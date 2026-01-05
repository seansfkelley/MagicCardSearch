import Logging
import SwiftUI
import ScryfallKit
import SwiftSoup

private let logger = Logger(label: "CardTagsSection")

struct CardTagsSection: View {
    let setCode: String
    let collectorNumber: String
    @State private var isExpanded = false
    @State private var card: LoadableResult<GraphQlCard, Error> = .unloaded
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
                        onRelationshipTapped: { relationshipId, oracleId in
                            Task {
                                await loadRelatedCard(relationshipId: relationshipId, oracleId: oracleId)
                            }
                        }
                    )
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
            let url = URL(string: "https://tagger.scryfall.com/card/\(setCode.lowercased())/\(collectorNumber.lowercased())")!

            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    throw URLError(
                        .badServerResponse,
                        userInfo: [
                            NSURLErrorFailingURLErrorKey: url,
                            NSLocalizedDescriptionKey: "bad server response code=\(statusCode)",
                        ]
                    )
                }

                guard let html = String(data: data, encoding: .utf8) else {
                    throw URLError(
                        .cannotDecodeContentData,
                        userInfo: [
                            NSURLErrorFailingURLErrorKey: url,
                            NSLocalizedDescriptionKey: "failed to decode HTML as UTF-8",
                        ]
                    )
                }

                guard let cookie = httpResponse.value(forHTTPHeaderField: "set-cookie") else {
                    throw URLError(
                        .badServerResponse,
                        userInfo: [
                            NSURLErrorFailingURLErrorKey: url,
                            NSLocalizedDescriptionKey: "Missing set-cookie header in response",
                        ]
                    )
                }

                let document = try SwiftSoup.parse(html)

                guard let csrfToken = try document.select("meta[name=csrf-token]").first()?.attr("content") else {
                    throw URLError(
                        .cannotParseResponse,
                        userInfo: [
                            NSURLErrorFailingURLErrorKey: url,
                            NSLocalizedDescriptionKey: "Missing CSRF token in HTML response",
                        ]
                    )
                }

                card = .loaded(try await runGraphQlQuery(cookie: cookie, csrfToken: csrfToken), nil)
            } catch {
                logger.error("error while trying to fetch tags", metadata: [
                    "url": "\(url)",
                    "error": "\(error)",
                ])
                card = .errored(card.latestValue, error)
            }
        }
    }

    private func loadRelatedCard(relationshipId: UUID, oracleId: UUID) async {
        loadingRelationshipId = relationshipId
        defer { loadingRelationshipId = nil }

        do {
            // Search for a card by oracle ID
            guard let fetchedCard = try await cardSearchService.fetchCard(byOracleId: oracleId) else {
                logger.error("no card found for oracle ID", metadata: [
                    "relationshipId": "\(relationshipId)",
                    "oracleId": "\(oracleId)",
                ])
                return
            }
            relatedCardToShow = fetchedCard
        } catch {
            // TODO: Handle error appropriately (e.g., show alert)
            logger.error("error loading related card from relationship", metadata: [
                "relationshipId": "\(relationshipId)",
                "oracleId": "\(oracleId)",
                "error": "\(error)",
            ])
        }
    }

    private func runGraphQlQuery(cookie: String, csrfToken: String) async throws -> GraphQlCard {
        let url = URL(string: "https://tagger.scryfall.com/graphql")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(csrfToken, forHTTPHeaderField: "X-CSRF-Token")
        request.setValue(cookie, forHTTPHeaderField: "Cookie")

        let query: [String: Any] = [
            "operationName": "FetchCard",
            "query": graphQlQuery,
            "variables": [
                "back": false,
                "moderatorView": false,
                "number": collectorNumber,
                "set": setCode.lowercased(),
            ],
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: query, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw URLError(
                .badServerResponse,
                userInfo: [
                    NSURLErrorFailingURLErrorKey: url,
                    NSLocalizedDescriptionKey: "GraphQL request failed with status code \(statusCode)",
                ]
            )
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let graphQlResponse = try decoder.decode(GraphQLResponse<FetchCardQuery>.self, from: data)
        return graphQlResponse.data.card
    }
}
private struct TagListView: View {
    let card: GraphQlCard
    let loadingRelationshipId: UUID?
    let onRelationshipTapped: (UUID, UUID) -> Void
    
    private var artworkTags: [GraphQlCard.Tagging] {
        card.taggings
            .filter { $0.tag.namespace == .artwork && $0.tag.status == .goodStanding }
            .sorted(using: KeyPathComparator(\.tag.name, comparator: .localizedStandard))
    }
    
    private var gameplayTags: [GraphQlCard.Tagging] {
        card.taggings
            .filter { $0.tag.namespace == .card && $0.tag.status == .goodStanding }
            .sorted(using: KeyPathComparator(\.tag.name, comparator: .localizedStandard))
    }
    
    private var relationships: [GraphQlCard.Relationship] {
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
    let taggings: [GraphQlCard.Tagging]
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
    let card: GraphQlCard
    let relationships: [GraphQlCard.Relationship]
    let loadingRelationshipId: UUID?
    let onRelationshipTapped: (UUID, UUID) -> Void

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
                        onTap: {
                            if let otherId = relationship.otherId(as: card),
                               relationship.foreignKey == .oracleId {
                                onRelationshipTapped(relationship.id, otherId)
                            }
                        }
                    )

                    if relationship.id != relationships.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.vertical, spacing)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func relationIcon(for classifier: GraphQlCard.Relationship.Classifier) -> String {
        switch classifier {
        case .similarTo, .relatedTo, .mirrors: "equal"
        case .betterThan: "greaterthan"
        case .worseThan: "lessthan"
        case .referencesTo: "arrowshape.turn.up.left"
        case .referencedBy: "arrowshape.turn.up.right"
        case .withBody: "person.slash"
        case .withoutBody: "person"
        case .colorshifted: "paintpalette"
        case .depicts, .depictedIn: "photo"
        case .comesAfter, .comesBefore: "arrow.left.arrow.right.circle"
        case .unknown: "questionmark.circle"
        }
    }
}

private struct TagRow: View {
    let tagging: GraphQlCard.Tagging
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
    let relationship: GraphQlCard.Relationship
    let card: GraphQlCard
    let isLoading: Bool
    let onTap: () -> Void
    @State private var showAnnotation = false
    @State private var popoverHeight: CGFloat = 0

    private let iconWidth: CGFloat = 20
    
    private var canTap: Bool {
        relationship.foreignKey == .oracleId
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
    private func relationIcon(for classifier: GraphQlCard.Relationship.Classifier) -> String {
        switch classifier {
        case .similarTo, .relatedTo, .mirrors: "equal"
        case .betterThan: "greaterthan"
        case .worseThan: "lessthan"
        case .referencesTo: "arrowshape.turn.up.left"
        case .referencedBy: "arrowshape.turn.up.right"
        case .withBody: "person.slash"
        case .withoutBody: "person"
        case .colorshifted: "paintpalette"
        case .depicts, .depictedIn: "photo"
        case .comesAfter, .comesBefore: "arrow.left.arrow.right.circle"
        case .unknown: "questionmark.circle"
        }
    }
}

private struct GraphQlCard: Codable {
    enum Status: Codable, Equatable {
        case goodStanding // This is the only case we care about.
        case unknown(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = switch rawValue {
            case "GOOD_STANDING": .goodStanding
            default: .unknown(rawValue)
            }
        }
    }

    enum ForeignKey: Codable, Equatable {
        case oracleId, illustrationId
        case unknown(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = switch rawValue {
            case "oracleId": .oracleId
            case "illustrationId": .illustrationId
            default: .unknown(rawValue)
            }
        }
    }

    struct Tagging: Codable {
        struct Tag: Codable {
            // swiftlint:disable:next nesting
            enum Namespace: Codable, Equatable {
                case artwork, card
                case unknown(String)
                
                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    let rawValue = try container.decode(String.self)
                    self = switch rawValue {
                    case "artwork": .artwork
                    case "card": .card
                    default: .unknown(rawValue)
                    }
                }
            }

            let ancestorTags: [Tag]?
            let createdAt: Date
            let description: String?
            let id: UUID
            let name: String
            let namespace: Namespace
            let slug: String
            let status: Status
        }

        enum Weight: Codable {
            // Is there such a thing as VERY_WEAK? I couldn't find any examples.
            case weak, median, strong, veryStrong
            case unknown(String)

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                let rawValue = try container.decode(String.self)
                self = switch rawValue {
                case "WEAK": .weak
                case "MEDIAN": .median
                case "STRONG": .strong
                case "VERY_STRONG": .median
                default: .unknown(rawValue)
                }
            }
        }

        let annotation: String?
        let createdAt: Date
        let foreignKey: ForeignKey
        let id: UUID
        let tag: Tag
        let weight: Weight
    }

    struct Relationship: Codable {
        enum Classifier: Codable {
            case betterThan, colorshifted, comesAfter, comesBefore, depictedIn, depicts, mirrors, referencedBy, referencesTo, relatedTo, similarTo, withBody, withoutBody, worseThan
            case unknown(String)

            // swiftlint:disable:next cyclomatic_complexity
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                let rawValue = try container.decode(String.self)
                self = switch rawValue {
                case "BETTER_THAN": .betterThan
                case "COLORSHIFTED": .colorshifted
                case "COMES_AFTER": .comesAfter
                case "COMES_BEFORE": .comesBefore
                case "DEPICTED_IN": .depictedIn
                case "DEPICTS": .depicts
                case "MIRRORS": .mirrors
                case "REFERENCED_BY": .referencedBy
                case "REFERENCES_TO": .referencesTo
                case "RELATED_TO": .relatedTo
                case "SIMILAR_TO": .similarTo
                case "WITH_BODY": .withBody
                case "WITHOUT_BODY": .withoutBody
                case "WORSE_THAN": .worseThan
                default: .unknown(rawValue)
                }
            }
        }

        let annotation: String?
        let createdAt: Date
        let classifier: Classifier
        let classifierInverse: Classifier
        let foreignKey: ForeignKey
        let id: UUID
        let relatedId: UUID
        let relatedName: String
        let status: Status
        let subjectId: UUID
        let subjectName: String

        func otherClassifier(as card: GraphQlCard) -> Relationship.Classifier? {
            let ownId = card.id(for: foreignKey)
            return if ownId == relatedId {
                classifierInverse
            } else if ownId == subjectId {
                classifier
            } else {
                nil
            }
        }

        func otherId(as card: GraphQlCard) -> UUID? {
            let ownId = card.id(for: foreignKey)
            return if ownId == relatedId {
                subjectId
            } else if ownId == subjectId {
                relatedId
            } else {
                nil
            }
        }

        func otherName(as card: GraphQlCard) -> String? {
            let ownId = card.id(for: foreignKey)
            return if ownId == relatedId {
                subjectName
            } else if ownId == subjectId {
                relatedName
            } else {
                nil
            }
        }
    }

    let oracleId: UUID
    let illustrationId: UUID
    let taggings: [Tagging]
    let relationships: [Relationship]

    func id(for foreignKey: ForeignKey) -> UUID? {
        switch foreignKey {
        case .oracleId: oracleId
        case .illustrationId: illustrationId
        case .unknown: nil
        }
    }
}

private struct GraphQLResponse<T: Codable>: Codable {
    let data: T
}

private struct FetchCardQuery: Codable {
    let card: GraphQlCard
}

private let graphQlQuery = """
query FetchCard(
  $set: String!
  $number: String!
  $back: Boolean = false
  $moderatorView: Boolean = false
) {
  card: cardBySet(set: $set, number: $number, back: $back) {
    ...CardAttrs
    backside
    flipsideDisplayName
    hasAlternateName
    layout
    scryfallUrl
    sideNames
    twoSided
    rotatedLayout
    taggings(moderatorView: $moderatorView) {
      ...TaggingAttrs
      tag {
        ...TagAttrs
        ancestorTags {
          ...TagAttrs
        }
      }
    }
    relationships(moderatorView: $moderatorView) {
      ...RelationshipAttrs
    }
  }
}

fragment CardAttrs on Card {
  artImageUrl
  backside
  cardImageUrl
  collectorNumber
  displayName
  id
  illustrationId
  name
  oracleId
  printingId
  set
}

fragment RelationshipAttrs on Relationship {
  classifier
  classifierInverse
  annotation
  subjectId
  subjectName
  createdAt
  creatorId
  foreignKey
  id
  name
  pendingRevisions
  relatedId
  relatedName
  status
  type
}

fragment TagAttrs on Tag {
  category
  createdAt
  creatorId
  id
  name
  namespace
  pendingRevisions
  slug
  status
  type
  hasExemplaryTagging
  description
}

fragment TaggingAttrs on Tagging {
  annotation
  subjectId
  createdAt
  creatorId
  foreignKey
  id
  pendingRevisions
  type
  status
  weight
}
"""
