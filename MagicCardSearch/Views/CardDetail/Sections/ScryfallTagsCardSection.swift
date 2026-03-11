import OSLog
import SwiftUI
import ScryfallKit
import SwiftSoup

private let logger = Logger(subsystem: "MagicCardSearch", category: "CardTagsSection")

@MainActor
protocol TagsService {
    func tags(forCollectorNumber collectorNumber: String, inSet setCode: String) async throws -> TaggerCard?
}

extension CachingScryfallService: TagsService {}

struct ScryfallTagsCardSection: View {
    @ScaledMetric private var iconWidth = CardDetailConstants.defaultSectionIconWidth

    let setCode: String
    let collectorNumber: String
    var searchState: Binding<SearchState>?
    let tagsService: TagsService

    @State private var isExpanded = false
    @State private var card: LoadableResult<TaggerCard?, Error> = .unloaded
    @State private var relatedCardToShow: Card?
    @State private var loadingRelationshipId: UUID?
    private let cardSearchService = CardSearchService()

    init(
        setCode: String,
        collectorNumber: String,
        searchState: Binding<SearchState>? = nil,
        tagsService: TagsService? = nil
    ) {
        self.setCode = setCode
        self.collectorNumber = collectorNumber
        self.searchState = searchState
        self.tagsService = tagsService ?? CachingScryfallService.shared
    }

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                switch card {
                case .unloaded, .loading:
                    ContentUnavailableView {
                        ProgressView()
                    } description: {
                        Text("Loading tags...")
                            .padding(.top)
                    }
                    .padding(.vertical)
                    .frame(maxWidth: .infinity, alignment: .center)
                case .errored(_, let error):
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
                case .loaded(let loadedCard, _):
                    if let cardValue = loadedCard, !cardValue.taggings.isEmpty || !cardValue.relationships.isEmpty {
                        TagListView(
                            card: cardValue,
                            loadingRelationshipId: loadingRelationshipId,
                            searchState: searchState,
                        ) { relationshipId, foreignKeyId, foreignKey in
                            Task {
                                await loadRelatedCard(
                                    relationshipId: relationshipId,
                                    foreignKeyId: foreignKeyId,
                                    foreignKey: foreignKey
                                )
                            }
                        }
                    } else {
                        ContentUnavailableView {
                            Label("No Tags", systemImage: "tag.slash")
                        } description: {
                            Text("This card doesn't have any tags yet.")
                        }
                        .padding(.vertical)
                    }
                }
            },
            label: {
                Label("Scryfall Tags", systemImage: "tag")
                    .labelReservedIconWidth(iconWidth)
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
                    searchState: searchState,
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
        Task {
            await LoadableResult<TaggerCard?, any Error>.load({ card = $0 }) {
                try await tagsService.tags(forCollectorNumber: collectorNumber, inSet: setCode)
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
    var searchState: Binding<SearchState>?
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
                    searchState: searchState,
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
                    searchState: searchState,
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
                    searchState: searchState,
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
    var searchState: Binding<SearchState>?
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
                        searchState: searchState
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
    var searchState: Binding<SearchState>?
    @State private var showAnnotation = false
    @State private var showWeightTooltip = false

    private var filterTerm: FilterTerm? {
        switch tagging.tag.namespace {
        case .artwork: .basic(.positive, "art", .including, tagging.tag.name)
        case .card: .basic(.positive, "function", .including, tagging.tag.name)
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

            if let explanation = TagWeightExplanation(tagging.weight) {
                Button {
                    showWeightTooltip = true
                } label: {
                    Image(systemName: explanation.iconName)
                        .foregroundStyle(explanation.color)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showWeightTooltip) {
                    AnnotationPopover(annotation: explanation.tooltip)
                }
                .padding(.leading, 8)
            }

            Spacer()

            if let filterTerm {
                Menu {
                    Button {
                        UIPasteboard.general.string = filterTerm.description
                    } label: {
                        Label("Copy as Filter", systemImage: "doc.on.clipboard.fill")
                    }

                    if let searchState {
                        if searchState.wrappedValue.filters.isEmpty {
                            Button {
                                searchState.wrappedValue.filters = [.term(filterTerm)]
                                searchState.wrappedValue.performSearch()
                            } label: {
                                Label("Search for this Tag", systemImage: "magnifyingglass")
                            }
                        } else {
                            Button {
                                searchState.wrappedValue.filters.append(.term(filterTerm))
                                searchState.wrappedValue.performSearch()
                            } label: {
                                Label("Add to Current Search", systemImage: "plus.magnifyingglass")
                            }
                            Button {
                                searchState.wrappedValue.filters = [.term(filterTerm)]
                                searchState.wrappedValue.performSearch()
                            } label: {
                                Label("Replace Current Search", systemImage: "magnifyingglass")
                            }
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

private struct TagWeightExplanation {
    let iconName: String
    let color: Color
    let tooltip: String

    init?(_ weight: TaggerCard.Tagging.Weight) {
        switch weight {
        case .weak:
            iconName = "arrowtriangle.down.fill"
            color = .red
            tooltip = "weak example"
        case .strong:
            iconName = "arrowtriangle.up.fill"
            color = .green
            tooltip = "good example"
        case .veryStrong:
            iconName = "star.fill"
            color = .yellow
            tooltip = "exemplary"
        case .median, .unknown:
            return nil
        }
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

// MARK: - Previews

private struct MockTagsService: TagsService {
    enum Behavior {
        case loaded(TaggerCard?)
        case loadingForever
        case errored(any Error)
    }

    let behavior: Behavior

    func tags(forCollectorNumber collectorNumber: String, inSet setCode: String) async throws -> TaggerCard? {
        switch behavior {
        case .loaded(let card):
            return card
        case .loadingForever:
            try await Task.sleep(for: .seconds(9999))
            return nil
        case .errored(let error):
            throw error
        }
    }
}

private let sampleOracleId = UUID()
private let sampleIllustrationId = UUID()
private let samplePrintingId = UUID()

private let sampleTaggerCard = TaggerCard(
    name: "Lightning Bolt",
    oracleId: sampleOracleId,
    illustrationId: sampleIllustrationId,
    printingId: samplePrintingId,
    taggings: [
        TaggerCard.Tagging(
            annotation: nil,
            createdAt: Date(),
            foreignKey: .oracleId,
            id: UUID(),
            tag: TaggerCard.Tagging.Tag(
                ancestorTags: nil,
                createdAt: Date(),
                description: nil,
                id: UUID(),
                name: "burn",
                namespace: .card,
                slug: "burn",
                status: .goodStanding
            ),
            weight: .veryStrong
        ),
        TaggerCard.Tagging(
            annotation: "Deals 3 damage for just one mana, the gold standard for red removal.",
            createdAt: Date(),
            foreignKey: .oracleId,
            id: UUID(),
            tag: TaggerCard.Tagging.Tag(
                ancestorTags: nil,
                createdAt: Date(),
                description: nil,
                id: UUID(),
                name: "removal",
                namespace: .card,
                slug: "removal",
                status: .goodStanding
            ),
            weight: .strong
        ),
        TaggerCard.Tagging(
            annotation: nil,
            createdAt: Date(),
            foreignKey: .printingId,
            id: UUID(),
            tag: TaggerCard.Tagging.Tag(
                ancestorTags: nil,
                createdAt: Date(),
                description: nil,
                id: UUID(),
                name: "classic frame",
                namespace: .print,
                slug: "classic-frame",
                status: .goodStanding
            ),
            weight: .median
        ),
        TaggerCard.Tagging(
            annotation: nil,
            createdAt: Date(),
            foreignKey: .illustrationId,
            id: UUID(),
            tag: TaggerCard.Tagging.Tag(
                ancestorTags: nil,
                createdAt: Date(),
                description: nil,
                id: UUID(),
                name: "lightning",
                namespace: .artwork,
                slug: "lightning",
                status: .goodStanding
            ),
            weight: .median
        ),
    ],
    relationships: [
        TaggerCard.Relationship(
            annotation: nil,
            createdAt: Date(),
            classifier: .similarTo,
            classifierInverse: .similarTo,
            foreignKey: .oracleId,
            id: UUID(),
            relatedId: sampleOracleId,
            relatedName: "Lightning Bolt",
            status: .goodStanding,
            subjectId: UUID(),
            subjectName: "Shock"
        ),
        TaggerCard.Relationship(
            annotation: nil,
            createdAt: Date(),
            classifier: .betterThan,
            classifierInverse: .worseThan,
            foreignKey: .oracleId,
            id: UUID(),
            relatedId: sampleOracleId,
            relatedName: "Lightning Bolt",
            status: .goodStanding,
            subjectId: UUID(),
            subjectName: "Shock"
        ),
        TaggerCard.Relationship(
            annotation: "Both cards deal damage to any target for low mana cost.",
            createdAt: Date(),
            classifier: .relatedTo,
            classifierInverse: .relatedTo,
            foreignKey: .oracleId,
            id: UUID(),
            relatedId: sampleOracleId,
            relatedName: "Lightning Bolt",
            status: .goodStanding,
            subjectId: UUID(),
            subjectName: "Char"
        ),
        TaggerCard.Relationship(
            annotation: nil,
            createdAt: Date(),
            classifier: .referencedBy,
            classifierInverse: .referencesTo,
            foreignKey: .oracleId,
            id: UUID(),
            relatedId: sampleOracleId,
            relatedName: "Lightning Bolt",
            status: .goodStanding,
            subjectId: UUID(),
            subjectName: "Forked Bolt"
        ),
        TaggerCard.Relationship(
            annotation: nil,
            createdAt: Date(),
            classifier: .colorshifted,
            classifierInverse: .colorshifted,
            foreignKey: .illustrationId,
            id: UUID(),
            relatedId: sampleIllustrationId,
            relatedName: "Lightning Bolt",
            status: .goodStanding,
            subjectId: UUID(),
            subjectName: "Chain Lightning"
        ),
    ]
)

#Preview("Loaded with tags") {
    ScrollView {
        ScryfallTagsCardSection(
            setCode: "lea",
            collectorNumber: "161",
            tagsService: MockTagsService(behavior: .loaded(sampleTaggerCard))
        )
    }
}

#Preview("Loading") {
    ScrollView {
        ScryfallTagsCardSection(
            setCode: "lea",
            collectorNumber: "161",
            tagsService: MockTagsService(behavior: .loadingForever)
        )
    }
}

#Preview("No tags") {
    ScrollView {
        ScryfallTagsCardSection(
            setCode: "lea",
            collectorNumber: "161",
            tagsService: MockTagsService(behavior: .loaded(nil))
        )
    }
}

#Preview("Errored") {
    ScrollView {
        ScryfallTagsCardSection(
            setCode: "lea",
            collectorNumber: "161",
            tagsService: MockTagsService(behavior: .errored(URLError(.notConnectedToInternet)))
        )
    }
}
