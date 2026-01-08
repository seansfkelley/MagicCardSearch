import OSLog
import SwiftUI
import ScryfallKit
import SwiftSoup

private let logger = Logger(subsystem: "MagicCardSearch", category: "CardTagsSection")

private enum LoadError: Error, LocalizedError {
    case cardNotFound

    var errorDescription: String? {
        switch self {
        case .cardNotFound: "Card tags not found"
        }
    }
}

struct CardTagsSection: View {
    @Binding var searchState: SearchState
    let setCode: String
    let collectorNumber: String
    @State private var isExpanded = false
    @State private var card: LoadableResult<TaggerCard, Error> = .unloaded
    @State private var relatedCardToShow: Card?
    @State private var loadingRelationshipId: UUID?
    private let cardSearchService = CardSearchService()

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                if case .loading = card {
                    ContentUnavailableView {
                        ProgressView()
                    } description: {
                        Text("Loading tags...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical)
                } else if case .errored(_, let error) = card {
                    ContentUnavailableView {
                        Label("Failed to Load Tags", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.localizedDescription)
                    } actions: {
                        Button("Try Again", action: loadTags)
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                    }
                    .padding(.vertical)
                } else if let cardValue = card.latestValue, cardValue.taggings.isEmpty && cardValue.relationships.isEmpty {
                    ContentUnavailableView {
                        Label("No Tags", systemImage: "tag.slash")
                    } description: {
                        Text("This card doesn't have any tags yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical)
                } else if let cardValue = card.latestValue {
                    TagListView(
                        card: cardValue,
                        loadingRelationshipId: loadingRelationshipId,
                        searchState: $searchState,
                    ) { relationshipId, foreignKeyId, foreignKey in
                        Task {
                            await loadRelatedCard(
                                relationshipId: relationshipId,
                                foreignKeyId: foreignKeyId,
                                foreignKey: foreignKey
                            )
                        }
                    }
                }
            },
            label: {
                Text("Scryfall Tags")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .padding(.vertical)
            }
        )
        .tint(.primary)
        .padding(.horizontal)
        .onChange(of: isExpanded) { _, expanded in
            if expanded, case .unloaded = card {
                loadTags()
            }
        }
        .sheet(item: $relatedCardToShow) { relatedCard in
            NavigationStack {
                CardDetailView(
                    card: relatedCard,
                    isFlipped: .constant(false),
                    searchState: $searchState,
                )
                .navigationTitle(relatedCard.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            relatedCardToShow = nil
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
            }
        }
    }

    private func loadTags() {
        card = .loading(nil, nil)

        Task {
            do {
                guard let loadedCard = try await TaggerCard.fetch(setCode: setCode, collectorNumber: collectorNumber) else {
                    throw LoadError.cardNotFound
                }
                card = .loaded(loadedCard, nil)
            } catch {
                logger.error("error while trying to fetch tagged card for set=\(setCode) collectorNumber=\(collectorNumber) error=\(error)")
                card = .errored(card.latestValue, error)
            }
        }
    }

    private func loadRelatedCard(relationshipId: UUID, foreignKeyId: UUID, foreignKey: TaggerCard.ForeignKey) async {
        loadingRelationshipId = relationshipId
        defer { loadingRelationshipId = nil }

        do {
            // Search for a card by the appropriate foreign key
            let fetchedCard: Card? = switch foreignKey {
            case .oracleId:
                try await cardSearchService.fetchCard(byOracleId: foreignKeyId)
            case .illustrationId:
                try await cardSearchService.fetchCard(byIllustrationId: foreignKeyId)
            case .printingId:
                try await cardSearchService.fetchCard(byPrintingId: foreignKeyId)
            case .unknown:
                nil
            }

            guard let fetchedCard else {
                logger.error("no related card found with foreignKeyId=\(foreignKeyId) ofType=\(foreignKey)")
                return
            }
            relatedCardToShow = fetchedCard
        } catch {
            // TODO: Handle error appropriately (e.g., show alert)
            logger.error("error loading related card with foreignKeyId=\(foreignKeyId) ofType=\(foreignKey) error=\(error)")
        }
    }
}

private struct TagListView: View {
    let card: TaggerCard
    let loadingRelationshipId: UUID?
    @Binding var searchState: SearchState
    let onRelationshipTapped: (UUID, UUID, TaggerCard.ForeignKey) -> Void

    private func tags(for namespace: TaggerCard.Tagging.Tag.Namespace) -> [TaggerCard.Tagging] {
        card.taggings
            .filter { $0.tag.namespace == namespace && $0.tag.status == .goodStanding }
            .sorted(using: KeyPathComparator(\.tag.name, comparator: .localizedStandard))
    }

    private func relationships(for foreignKey: TaggerCard.ForeignKey) -> [TaggerCard.Relationship] {
        card.relationships
            .filter { $0.foreignKey == foreignKey && $0.status == .goodStanding }
            .sorted {
                let lhsName = $0.otherName(as: card) ?? ""
                let rhsName = $1.otherName(as: card) ?? ""
                return lhsName.localizedStandardCompare(rhsName) == .orderedAscending
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let gameplayTags = tags(for: .card)
            let gameplayRelationships = relationships(for: .oracleId)
            let artworkTags = tags(for: .artwork)
            let artworkRelationships = relationships(for: .illustrationId)
            let printingTags = tags(for: .print)
            let printingRelationships = relationships(for: .printingId)
            
            let hasGameplay = !gameplayTags.isEmpty || !gameplayRelationships.isEmpty
            let hasArtwork = !artworkTags.isEmpty || !artworkRelationships.isEmpty
            let hasPrinting = !printingTags.isEmpty || !printingRelationships.isEmpty

            if hasGameplay {
                CombinedSectionView(
                    title: "Gameplay",
                    tagIconName: "list.bullet.rectangle.portrait",
                    tags: gameplayTags,
                    relationships: gameplayRelationships,
                    card: card,
                    loadingRelationshipId: loadingRelationshipId,
                    searchState: $searchState,
                    onRelationshipTapped: onRelationshipTapped
                )
            }

            if hasArtwork {
                if hasGameplay {
                    Spacer().frame(height: 20)
                }

                CombinedSectionView(
                    title: "Artwork",
                    tagIconName: "paintbrush.pointed",
                    tags: artworkTags,
                    relationships: artworkRelationships,
                    card: card,
                    loadingRelationshipId: loadingRelationshipId,
                    searchState: $searchState,
                    onRelationshipTapped: onRelationshipTapped
                )
            }

            if hasPrinting {
                if hasGameplay || hasArtwork {
                    Spacer().frame(height: 20)
                }

                CombinedSectionView(
                    title: "Printing",
                    tagIconName: "printer",
                    tags: printingTags,
                    relationships: printingRelationships,
                    card: card,
                    loadingRelationshipId: loadingRelationshipId,
                    searchState: $searchState,
                    onRelationshipTapped: onRelationshipTapped
                )
            }
        }
    }
}

private struct CombinedSectionView: View {
    let title: String
    let tagIconName: String
    let tags: [TaggerCard.Tagging]
    let relationships: [TaggerCard.Relationship]
    let card: TaggerCard
    let loadingRelationshipId: UUID?
    @Binding var searchState: SearchState
    let onRelationshipTapped: (UUID, UUID, TaggerCard.ForeignKey) -> Void

    private let spacing: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(title) (\(tags.count + relationships.count))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
                .padding(.bottom, 8)

            VStack(spacing: spacing) {
                ForEach(tags, id: \.tag.id) { tagging in
                    TagRow(
                        tagging: tagging,
                        iconName: tagIconName,
                        searchState: $searchState
                    )

                    if tagging.tag.id != tags.last?.tag.id || !relationships.isEmpty {
                        Divider()
                    }
                }

                ForEach(relationships, id: \.id) { relationship in
                    RelationshipRow(
                        relationship: relationship,
                        card: card,
                        isLoading: loadingRelationshipId == relationship.id,
                        onTap: onRelationshipTapped,
                    )

                    if relationship.id != relationships.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.vertical, spacing)
        }
    }
}

private struct TagRow: View {
    let tagging: TaggerCard.Tagging
    let iconName: String
    @Binding var searchState: SearchState
    @State private var showAnnotation = false

    private var searchFilter: SearchFilter? {
        switch tagging.tag.namespace {
        case .artwork: SearchFilter.basic(false, "art", .including, tagging.tag.name)
        case .card: SearchFilter.basic(false, "function", .including, tagging.tag.name)
        case .print: nil
        case .unknown: nil
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)

            Text(tagging.tag.name)
                .font(.body)
                .foregroundStyle(.primary)

            if let annotation = tagging.annotation, !annotation.isEmpty {
                Button {
                    showAnnotation = true
                } label: {
                    Image(systemName: "text.bubble")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showAnnotation) {
                    AnnotationPopover(annotation: annotation)
                }
                .padding(.leading, 8)
            }

            Group {
                switch tagging.weight {
                case .weak: Image(systemName: "arrowtriangle.down.fill").foregroundStyle(.red)
                case .median: EmptyView()
                case .strong: Image(systemName: "arrowtriangle.up.fill").foregroundStyle(.green)
                case .veryStrong: Image(systemName: "star.fill").foregroundStyle(.yellow)
                case .unknown: EmptyView()
                }
            }
            .padding(.leading, 8)

            Spacer()

            if let searchFilter {
                Menu {
                    Button {
                        UIPasteboard.general.string = searchFilter.description
                    } label: {
                        Label("Copy as Filter", systemImage: "doc.on.clipboard.fill")
                    }

                    if searchState.filters.isEmpty {
                        Button {
                            searchState.filters = [searchFilter]
                            searchState.performSearch()
                        } label: {
                            Label("Search for this Tag", systemImage: "magnifyingglass")
                        }
                    } else {
                        Button {
                            searchState.filters.append(searchFilter)
                            searchState.performSearch()
                        } label: {
                            Label("Add to Current Search", systemImage: "plus.magnifyingglass")
                        }
                        Button {
                            searchState.filters = [searchFilter]
                            searchState.performSearch()
                        } label: {
                            Label("Replace Current Search", systemImage: "magnifyingglass")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .menuStyle(.borderlessButton)
                .menuActionDismissBehavior(.automatic)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RelationshipRow: View {
    let relationship: TaggerCard.Relationship
    let card: TaggerCard
    let isLoading: Bool
    let onTap: (UUID, UUID, TaggerCard.ForeignKey) -> Void
    @State private var showAnnotation = false

    private let iconWidth: CGFloat = 20

    var body: some View {
        Button {
            if let otherId = relationship.otherId(as: card) {
                onTap(relationship.id, otherId, relationship.foreignKey)
            }
        } label: {
            HStack(spacing: 8) {
                if let classifier = relationship.otherClassifier(as: card) {
                    relationIcon(for: classifier)
                        .foregroundStyle(.secondary)
                        .frame(width: iconWidth)
                }

                Text(relationship.otherName(as: card) ?? "Unknown")
                    .font(.body)
                    .foregroundStyle(.primary)

                if let annotation = relationship.annotation, !annotation.isEmpty {
                    Button {
                        showAnnotation = true
                    } label: {
                        Image(systemName: "text.bubble")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showAnnotation) {
                        AnnotationPopover(annotation: annotation)
                    }
                    .padding(.leading, 8)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(relationship.otherId(as: card) == nil)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func relationIcon(for classifier: TaggerCard.Relationship.Classifier) -> some View {
        let symbolName = switch classifier {
        case .similarTo, .relatedTo, .mirrors: "equal"
        case .betterThan: "greaterthan"
        case .worseThan: "lessthan"
        case .referencesTo: "arrow.turn.up.right"
        case .referencedBy: "arrow.turn.left.down"
        case .withBody: "person.slash"
        case .withoutBody: "person"
        case .colorshifted: "circle.lefthalf.filled.inverse"
        case .depictedIn: "arrow.turn.up.right"
        case .depicts: "arrow.turn.up.left"
        case .comesAfter: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .comesBefore: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .unknown: "questionmark.circle"
        }
        
        return Image(systemName: symbolName)
            .scaleEffect(x: classifier == .comesBefore ? -1 : 1)
    }
}

private struct AnnotationPopover: View {
    struct HeightKey: PreferenceKey {
        static let defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    let annotation: String
    @State private var popoverHeight: CGFloat = 0

    var body: some View {
        VStack {
            Text(annotation)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: HeightKey.self,
                            value: proxy.size.height,
                        )
                    }
                )
        }
        .frame(maxWidth: 300)
        .frame(idealHeight: popoverHeight)
        .onPreferenceChange(HeightKey.self) { popoverHeight = $0 }
        .presentationCompactAdaptation(.popover)
    }
}
