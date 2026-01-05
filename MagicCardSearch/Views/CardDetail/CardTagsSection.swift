import Logging
import SwiftUI
import ScryfallKit
import SwiftSoup

private let logger = Logger(label: "CardTagsSection")

struct CardTagsSection: View {
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
                CardDetailView(card: relatedCard, isFlipped: .constant(false))
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
                if let loadedCard = try await TaggerCard.fetch(setCode: setCode, collectorNumber: collectorNumber) {
                    card = .loaded(loadedCard, nil)
                } else {
                    card = .errored(nil, NSError(domain: "Tagger", code: -1, userInfo: nil))
                }
            } catch {
                logger.error("error while trying to fetch tags", metadata: [
                    "error": "\(error)",
                ])
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
                logger.error("no card found for foreign key", metadata: [
                    "relationshipId": "\(relationshipId)",
                    "foreignKey": "\(foreignKey)",
                    "foreignKeyId": "\(foreignKeyId)",
                ])
                return
            }
            relatedCardToShow = fetchedCard
        } catch {
            // TODO: Handle error appropriately (e.g., show alert)
            logger.error("error loading related card from relationship", metadata: [
                "relationshipId": "\(relationshipId)",
                "foreignKey": "\(foreignKey)",
                "foreignKeyId": "\(foreignKeyId)",
                "error": "\(error)",
            ])
        }
    }
}

private struct TagListView: View {
    let card: TaggerCard
    let loadingRelationshipId: UUID?
    let onRelationshipTapped: (UUID, UUID, TaggerCard.ForeignKey) -> Void

    private var artworkTags: [TaggerCard.Tagging] {
        card.taggings
            .filter { $0.tag.namespace == .artwork && $0.tag.status == .goodStanding }
            .sorted(using: KeyPathComparator(\.tag.name, comparator: .localizedStandard))
    }

    private var gameplayTags: [TaggerCard.Tagging] {
        card.taggings
            .filter { $0.tag.namespace == .card && $0.tag.status == .goodStanding }
            .sorted(using: KeyPathComparator(\.tag.name, comparator: .localizedStandard))
    }

    private var relationships: [TaggerCard.Relationship] {
        card.relationships
            .filter { $0.status == .goodStanding }
            .sorted {
                let lhsName = $0.otherName(as: card) ?? ""
                let rhsName = $1.otherName(as: card) ?? ""
                return lhsName.localizedStandardCompare(rhsName) == .orderedAscending
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !artworkTags.isEmpty {
                TagSectionView(
                    title: "Artwork",
                    taggings: artworkTags,
                    iconName: "paintbrush.pointed",
                )
            }

            if !gameplayTags.isEmpty {
                if !artworkTags.isEmpty {
                    Spacer().frame(height: 20)
                }

                TagSectionView(
                    title: "Gameplay",
                    taggings: gameplayTags,
                    iconName: "list.bullet.rectangle.portrait",
                )
            }

            if !relationships.isEmpty {
                if !artworkTags.isEmpty || !gameplayTags.isEmpty {
                    Spacer().frame(height: 20)
                }

                RelatedCardsSectionView(
                    card: card,
                    relationships: relationships,
                    loadingRelationshipId: loadingRelationshipId,
                    onRelationshipTapped: onRelationshipTapped
                )
            }
        }
    }
}

private struct TagSectionView: View {
    let title: String
    let taggings: [TaggerCard.Tagging]
    let iconName: String

    private let spacing: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
                .padding(.bottom, 8)

            VStack(spacing: spacing) {
                ForEach(taggings, id: \.tag.id) { tagging in
                    TagRow(tagging: tagging, iconName: iconName)

                    if tagging.tag.id != taggings.last?.tag.id {
                        Divider()
                    }
                }
            }
            .padding(.vertical, spacing)
        }
    }
}

private struct RelatedCardsSectionView: View {
    let card: TaggerCard
    let relationships: [TaggerCard.Relationship]
    let loadingRelationshipId: UUID?
    let onRelationshipTapped: (UUID, UUID, TaggerCard.ForeignKey) -> Void

    private let spacing: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Related Cards")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
                .padding(.bottom, 8)

            VStack(spacing: spacing) {
                ForEach(relationships, id: \.id) { relationship in
                    RelationshipRow(
                        relationship: relationship,
                        card: card,
                        isLoading: loadingRelationshipId == relationship.id,
                    ) {
                        if let otherId = relationship.otherId(as: card),
                           relationship.foreignKey == .oracleId || relationship.foreignKey == .illustrationId || relationship.foreignKey == .printingId {
                            onRelationshipTapped(relationship.id, otherId, relationship.foreignKey)
                        }
                    }

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
    @State private var showAnnotation = false
    @State private var popoverHeight: CGFloat = 0

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)

            Text(tagging.tag.name)
                .font(.body)

            if let annotation = tagging.annotation, !annotation.isEmpty {
                Button {
                    showAnnotation = true
                } label: {
                    Image(systemName: "text.bubble")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showAnnotation) {
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
                    .frame(idealWidth: 300, idealHeight: popoverHeight)
                    .onPreferenceChange(HeightKey.self) { popoverHeight = $0 }
                    .presentationCompactAdaptation(.popover)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct RelationshipRow: View {
    let relationship: TaggerCard.Relationship
    let card: TaggerCard
    let isLoading: Bool
    let onTap: () -> Void
    @State private var showAnnotation = false
    @State private var popoverHeight: CGFloat = 0

    private let iconWidth: CGFloat = 20

    private var canTap: Bool {
        relationship.foreignKey == .oracleId || relationship.foreignKey == .illustrationId || relationship.foreignKey == .printingId
    }

    var body: some View {
        Button {
            if canTap {
                onTap()
            }
        } label: {
            HStack(spacing: 8) {
                if let classifier = relationship.otherClassifier(as: card) {
                    Image(systemName: relationIcon(for: classifier))
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
                        .frame(idealWidth: 300, idealHeight: popoverHeight)
                        .onPreferenceChange(HeightKey.self) { popoverHeight = $0 }
                        .presentationCompactAdaptation(.popover)
                    }
                    .padding(.leading, 8)
                }

                Spacer()

                if canTap {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canTap)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func relationIcon(for classifier: TaggerCard.Relationship.Classifier) -> String {
        switch classifier {
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
            // before should be flipped
        case .comesBefore: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .unknown: "questionmark.circle"
        }
    }
}
