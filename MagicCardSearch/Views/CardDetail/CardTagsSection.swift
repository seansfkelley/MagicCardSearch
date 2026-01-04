import Logging
import SwiftUI
import ScryfallKit
import SwiftSoup

private let logger = Logger(label: "CardTagsSection")

enum TagType {
    case artwork, function, similar, greater, lesser, references, unknown
}

struct CardTagsSection: View {
    let setCode: String
    let collectorNumber: String
    @State private var isExpanded = false
    @State private var tags: LoadableResult<(artwork: [String], gameplay: [String]), Error> = .unloaded

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                let artworkTags = tags.latestValue?.artwork ?? []
                let gameplayTags = tags.latestValue?.gameplay ?? []

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
                } else if artworkTags.isEmpty && gameplayTags.isEmpty {
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


            } catch {
                logger.error("error while trying to scrape tags", metadata: [
                    "url": "\(url)",
                    "error": "\(error)",
                ])
            }
        }

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            
            await MainActor.run {
                let artworkTags = ["Dragons", "Mountains", "Fire", "Detailed Background"]
                let gameplayTags = ["Removal", "Board Wipe", "Red Staple", "Commander"]
                tags = .loaded((artwork: artworkTags, gameplay: gameplayTags), nil)
            }
        }
    }
}
