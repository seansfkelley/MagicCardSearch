import SwiftUI
import ScryfallKit

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
            try? await Task.sleep(for: .seconds(1.5))
            
            await MainActor.run {
                let artworkTags = ["Dragons", "Mountains", "Fire", "Detailed Background"]
                let gameplayTags = ["Removal", "Board Wipe", "Red Staple", "Commander"]
                tags = .loaded((artwork: artworkTags, gameplay: gameplayTags), nil)
            }
        }
    }
}
