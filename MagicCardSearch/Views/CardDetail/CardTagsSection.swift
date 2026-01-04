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
                    VStack(alignment: .leading, spacing: 0) {
                        if !artworkTags.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Artwork")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                    .padding(.top, 12)
                                    .padding(.bottom, 6)

                                ForEach(artworkTags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.body)
                                        .padding(.horizontal)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }

                        if !gameplayTags.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Gameplay")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                    .padding(.top, artworkTags.isEmpty ? 12 : 16)
                                    .padding(.bottom, 6)

                                ForEach(gameplayTags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.body)
                                        .padding(.horizontal)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
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

                let document = try SwiftSoup.parse(html)
                let tagRows = try document.select(".tag-row")
                tags = .loaded(tagRows.compactMap(scrapeTag), nil)
            } catch {
                logger.error("error while trying to scrape tags", metadata: [
                    "url": "\(url)",
                    "error": "\(error)",
                ])
                tags = .errored(tags.latestValue, error)
            }
        }
    }

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
