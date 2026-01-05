import Logging
import SwiftUI
import ScryfallKit
import SwiftSoup

private let logger = Logger(label: "CardTagsSection")

enum ScryfallTag {
    enum Relationship {
        case similarTo, strictlyBetterThan, strictlyWorseThan, references, withBody, colorshifted
    }

    case artwork(String)
    case function(String)
    case relation(Relationship, UUID, String)
}

struct CardTagsSection: View {
    let setCode: String
    let collectorNumber: String
    @State private var isExpanded = false
    @State private var tags: LoadableResult<[ScryfallTag], Error> = .unloaded

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                if case .loading = tags {
                    ContentUnavailableView {
                        ProgressView()
                    } description: {
                        Text("Loading tags...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical)
                } else if case .errored(_, let error) = tags {
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
                } else if (tags.latestValue ?? []).isEmpty {
                    ContentUnavailableView {
                        Label("No Tags", systemImage: "tag.slash")
                    } description: {
                        Text("This card doesn't have any tags yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical)
                } else {
                    TagListView(tags: tags.latestValue ?? [])
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
            if expanded, case .unloaded = tags {
                loadTags()
            }
        }
    }
    
    private func loadTags() {
        tags = .loading(nil, nil)

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
                    // TODO: throw
                    return
                }

                guard let csrfToken = try document.select("meta[name=csrf-token]").first()?.attr("content") else {
                    // TODO: throw
                    return
                }

                let data = runGraphQlQuery(cookie: cookie, csrfToken: csrfToken)
            } catch {
                logger.error("error while trying to scrape tags", metadata: [
                    "url": "\(url)",
                    "error": "\(error)",
                ])
                tags = .errored(tags.latestValue, error)
            }
        }
    }

    private func runGraphQlQuery(cookie: String, csrfToken: String) async throws {
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
            ]
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
        
        // TODO: Parse and process the GraphQL response
        logger.debug("GraphQL response received", metadata: ["dataSize": "\(data.count)"])
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func scrapeTag(from tagRow: Element) -> ScryfallTag? {
        do {
            guard let anchor = try tagRow.select("a").first() else { return nil }
            guard let icon = try tagRow.select(".tagging-icon").first() else { return nil }

            let classes = Set(try icon.classNames())

            if classes.contains("value-artwork") {
                let tag = try anchor.text()
                return tag.isEmpty ? nil : .artwork(tag)
            } else if classes.contains("value-card") {
                let tag = try anchor.text()
                return tag.isEmpty ? nil : .function(tag)
            } else if classes.contains("value-referenced-by") {
                return try scrapeRelatedCard(from: anchor, withRelation: .references)
            } else if classes.contains("value-similar-to") {
                return try scrapeRelatedCard(from: anchor, withRelation: .similarTo)
            } else if classes.contains("value-with-body") {
                return try scrapeRelatedCard(from: anchor, withRelation: .withBody)
            } else if classes.contains("value-better-than") {
                return try scrapeRelatedCard(from: anchor, withRelation: .strictlyBetterThan)
            } else if classes.contains("value-worse-than") {
                return try scrapeRelatedCard(from: anchor, withRelation: .strictlyWorseThan)
            } else if classes.contains("value-colorshifted") {
                return try scrapeRelatedCard(from: anchor, withRelation: .colorshifted)
            } else {
                return nil
            }
        } catch {
            logger.error("error while trying to scrape Scryfall tag", metadata: [
                "error": "\(error)",
            ])
            return nil
        }
    }

    private func scrapeRelatedCard(from anchor: Element, withRelation relation: ScryfallTag.Relationship) throws -> ScryfallTag? {
        let name = try anchor.text()
        guard let rawOracleId = anchor.dataset()["hovercard"]?.suffix(from: "oracleid:".endIndex) else {
            return nil
        }
        guard let oracleId = UUID(uuidString: String(rawOracleId)) else {
            return nil
        }
        return .relation(relation, oracleId, name)
    }
}
private struct TagListView: View {
    let tags: [ScryfallTag]
    
    private var artworkTags: [String] {
        tags.compactMap { tag -> String? in
            if case .artwork(let value) = tag { return value }
            return nil
        }
    }
    
    private var gameplayTags: [String] {
        tags.compactMap { tag -> String? in
            if case .function(let value) = tag { return value }
            return nil
        }
    }
    
    private var relatedCards: [(ScryfallTag.Relationship, UUID, String)] {
        tags.compactMap { tag -> (ScryfallTag.Relationship, UUID, String)? in
            if case .relation(let relation, let id, let name) = tag {
                return (relation, id, name)
            }
            return nil
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !artworkTags.isEmpty {
                TagSectionView(
                    title: "Artwork",
                    tags: artworkTags,
                    isFirstSection: true
                )
            }
            
            if !gameplayTags.isEmpty {
                TagSectionView(
                    title: "Gameplay",
                    tags: gameplayTags,
                    isFirstSection: artworkTags.isEmpty
                )
            }
            
            if !relatedCards.isEmpty {
                RelatedCardsSectionView(
                    relatedCards: relatedCards,
                    isFirstSection: artworkTags.isEmpty && gameplayTags.isEmpty
                )
            }
        }
    }
}

private struct TagSectionView: View {
    let title: String
    let tags: [String]
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
            
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.body)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct RelatedCardsSectionView: View {
    let relatedCards: [(ScryfallTag.Relationship, UUID, String)]
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
            
            ForEach(relatedCards, id: \.1) { relation, cardId, cardName in
                HStack(spacing: 8) {
                    Image(systemName: relationIcon(for: relation))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(cardName)
                        .font(.body)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private func relationIcon(for relationship: ScryfallTag.Relationship) -> String {
        switch relationship {
        case .similarTo:
            return "equal.circle"
        case .strictlyBetterThan:
            return "arrow.up.circle"
        case .strictlyWorseThan:
            return "arrow.down.circle"
        case .references:
            return "link.circle"
        case .withBody:
            return "person.circle"
        case .colorshifted:
            return "paintpalette"
        }
    }
}

private struct FetchCard {
    enum Status: String {
        case REJECTED, GOOD_STANDING // what else?
    }

    struct Tagging {
        struct Tag {
            enum Namespace: String {
                case artwork, card
            }

            let name: String
            let slug: String
            let namespace: Namespace
            let description: String?
            let status: Status // make this nilable and don't fail the parse if it's not there
        }

        let tag: Tag
    }

    struct Relationship {
        enum Classifier: String {
            case BETTER_THAN, WORSE_THAN, COLORSHIFTED, REFERENCED_BY, SIMILAR_TO, REFERENCES_TO
        }

        let classifier: Classifier
        let relatedId: UUID
        let relatedName: String
        let status: Status
    }

    let taggings: [Tagging]
    let relationships: [Relationship]
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
