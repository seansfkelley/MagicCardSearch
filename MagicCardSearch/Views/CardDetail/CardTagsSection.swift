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
                    TagListView(card: cardValue)
                }
            },
            label: {
                Text("Scryfall Tags")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
        )
        .tint(.primary)
        .padding()
        .onChange(of: isExpanded) { _, expanded in
            if expanded, case .unloaded = card {
                loadTags()
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
                logger.error("error while trying to scrape tags", metadata: [
                    "url": "\(url)",
                    "error": "\(error)",
                ])
                card = .errored(card.latestValue, error)
            }
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
    
    private var artworkTags: [GraphQlCard.Tagging] {
        card.taggings.filter { $0.tag.namespace == .artwork && $0.tag.status == .goodStanding }
    }
    
    private var gameplayTags: [GraphQlCard.Tagging] {
        card.taggings.filter { $0.tag.namespace == .card && $0.tag.status == .goodStanding }
    }
    
    private var relationships: [GraphQlCard.Relationship] {
        card.relationships.filter { $0.status == .goodStanding }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !artworkTags.isEmpty {
                TagSectionView(
                    title: "Artwork",
                    taggings: artworkTags,
                    isFirstSection: true
                )
            }
            
            if !gameplayTags.isEmpty {
                TagSectionView(
                    title: "Gameplay",
                    taggings: gameplayTags,
                    isFirstSection: artworkTags.isEmpty
                )
            }
            
            if !relationships.isEmpty {
                RelatedCardsSectionView(
                    relationships: relationships,
                    isFirstSection: artworkTags.isEmpty && gameplayTags.isEmpty
                )
            }
        }
    }
}

private struct TagSectionView: View {
    let title: String
    let taggings: [GraphQlCard.Tagging]
    let isFirstSection: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, isFirstSection ? 12 : 16)
                .padding(.bottom, 6)
            
            ForEach(taggings, id: \.tag.slug) { tagging in
                Text(tagging.tag.name)
                    .font(.body)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct RelatedCardsSectionView: View {
    let relationships: [GraphQlCard.Relationship]
    let isFirstSection: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Related Cards")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, isFirstSection ? 12 : 16)
                .padding(.bottom, 6)
            
            ForEach(relationships, id: \.relatedId) { relationship in
                HStack(spacing: 8) {
                    Image(systemName: relationIcon(for: relationship.classifier))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(relationship.relatedName)
                        .font(.body)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private func relationIcon(for classifier: GraphQlCard.Relationship.Classifier) -> String {
        switch classifier {
        case .similarTo, .relatedTo, .mirrors:
            return "equal.circle"
        case .betterThan:
            return "arrow.up.circle"
        case .worseThan:
            return "arrow.down.circle"
        case .referencesTo, .referencedBy:
            return "link.circle"
        case .withBody, .withoutBody:
            return "person.circle"
        case .colorshifted:
            return "paintpalette"
        case .depicts, .depictedIn:
            return "photo.circle"
        case .comesAfter, .comesBefore:
            return "arrow.left.arrow.right.circle"
        case .unknown:
            return "questionmark.circle"
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

            let createdAt: Date
            let name: String
            let slug: String
            let namespace: Namespace
            let description: String?
            let status: Status
            let ancestorTags: [Tag]?
        }

        let annotation: String?
        let createdAt: Date
        let tag: Tag
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

        let createdAt: Date
        let classifier: Classifier
        let relatedId: UUID
        let relatedName: String
        let status: Status
    }

    let taggings: [Tagging]
    let relationships: [Relationship]
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
