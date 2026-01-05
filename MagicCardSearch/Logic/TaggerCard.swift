import Foundation
import SwiftSoup

struct TaggerCard: Codable {
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
        case oracleId, illustrationId, printingId
        case unknown(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = switch rawValue {
            case "oracleId": .oracleId
            case "illustrationId": .illustrationId
            case "printingId": .printingId
            default: .unknown(rawValue)
            }
        }
    }

    struct Tagging: Codable {
        struct Tag: Codable {
            // swiftlint:disable:next nesting
            enum Namespace: Codable, Equatable {
                case artwork, card, print
                case unknown(String)

                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    let rawValue = try container.decode(String.self)
                    self = switch rawValue {
                    case "artwork": .artwork
                    case "card": .card
                    case "print": .print
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
        enum Classifier: Codable, Equatable {
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

        func otherClassifier(as card: TaggerCard) -> Relationship.Classifier? {
            let ownId = card.id(for: foreignKey)
            return if ownId == relatedId {
                classifierInverse
            } else if ownId == subjectId {
                classifier
            } else {
                nil
            }
        }

        func otherId(as card: TaggerCard) -> UUID? {
            let ownId = card.id(for: foreignKey)
            return if ownId == relatedId {
                subjectId
            } else if ownId == subjectId {
                relatedId
            } else {
                nil
            }
        }

        func otherName(as card: TaggerCard) -> String? {
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
    let printingId: UUID
    let taggings: [Tagging]
    let relationships: [Relationship]

    func id(for foreignKey: ForeignKey) -> UUID? {
        switch foreignKey {
        case .oracleId: oracleId
        case .illustrationId: illustrationId
        case .printingId: printingId
        case .unknown: nil
        }
    }

    public static func fetch(setCode: String, collectorNumber: String) async throws -> TaggerCard? {
        let (cookie, csrfToken) = try await getHeaders(setCode: setCode, collectorNumber: collectorNumber)
        return try await runGraphQlQuery(cookie: cookie, csrfToken: csrfToken, setCode: setCode, collectorNumber: collectorNumber)
    }

    private static func getHeaders(setCode: String, collectorNumber: String) async throws -> (cookie: String, csrfToken: String) {
        let url = URL(string: "https://tagger.scryfall.com/card/\(setCode.lowercased())/\(collectorNumber.lowercased())")!

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

        return (cookie, csrfToken)
    }

    private static func runGraphQlQuery(
        cookie: String,
        csrfToken: String,
        setCode: String,
        collectorNumber: String,
    ) async throws -> TaggerCard {
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

private struct GraphQLResponse<T: Codable>: Codable {
    let data: T
}

private struct FetchCardQuery: Codable {
    let card: TaggerCard
}

private let graphQlQuery = """
query FetchCard(
  $set: String!
  $number: String!
) {
  card: cardBySet(set: $set, number: $number, back: false) {
    ...CardAttrs
    backside
    flipsideDisplayName
    hasAlternateName
    layout
    scryfallUrl
    sideNames
    twoSided
    rotatedLayout
    taggings(moderatorView: false) {
      ...TaggingAttrs
      tag {
        ...TagAttrs
        ancestorTags {
          ...TagAttrs
        }
      }
    }
    relationships(moderatorView: false) {
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
