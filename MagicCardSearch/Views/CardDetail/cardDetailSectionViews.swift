import SwiftUI
import ScryfallKit

// MARK: - Card Stat Section
struct CardStatSection: View {
    let value: String
    let label: String?
    
    init(value: String, label: String? = nil) {
        self.value = value
        self.label = label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                if let label = label {
                    Text("\(label):")
                        .font(.body)
                        .fontWeight(.semibold)
                }
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card Artist Section

struct CardArtistSection: View {
    let artist: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image("artist-nib")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                Text(artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card Legalities Section

struct CardLegalitiesSection: View {
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LegalityListView(card: card)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card Set Information Section

struct CardSetInfoSection: View {
    let setCode: String
    let setName: String
    let collectorNumber: String
    let rarity: Card.Rarity
    let lang: String
    let releasedAtAsDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                SetIconView(setCode: SetCode(setCode))

                VStack(alignment: .leading, spacing: 4) {
                    Text(setName)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    let suffix: String? = if let releaseDate = releasedAtAsDate {
                        releaseDate.formatted(.dateTime.year().month().day())
                    } else {
                        nil
                    }
                    
                    Text([
                        "\(setCode.uppercased()) #\(collectorNumber)",
                        rarity.rawValue.capitalized,
                        languageDisplay(for: lang),
                        suffix,
                    ].compactMap(\.self).joined(separator: " • ")
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func languageDisplay(for lang: String) -> String {
        let languages: [String: String] = [
            "en": "English",
            "es": "Spanish",
            "fr": "French",
            "de": "German",
            "it": "Italian",
            "pt": "Portuguese",
            "ja": "Japanese",
            "ko": "Korean",
            "ru": "Russian",
            "zhs": "Simplified Chinese",
            "zht": "Traditional Chinese",
            "he": "Hebrew",
            "la": "Latin",
            "grc": "Ancient Greek",
            "ar": "Arabic",
            "sa": "Sanskrit",
            "px": "Phyrexian",
        ]
        return languages[lang.lowercased()] ?? lang.capitalized
    }
}

// MARK: - Card Related Parts Section

struct CardRelatedPartsSection: View {
    let otherParts: [Card.RelatedCard]
    let isLoadingRelatedCard: Bool
    let onPartTapped: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Related Parts")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
                .padding(.vertical, 12)

            ForEach(otherParts.sorted { $0.name < $1.name }) { part in
                Button {
                    onPartTapped(part.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(part.name)
                                .font(.body)
                                .foregroundStyle(.primary)

                            Text(part.typeLine)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if isLoadingRelatedCard {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if part.id != otherParts.last?.id {
                    Divider()
                        .padding(.leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card Rulings Section

struct CardRulingsSection: View {
    let rulings: LoadableResult<[Card.Ruling], Error>
    let onRetry: () -> Void
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                if case .loading = rulings {
                    HStack {
                        Text("Loading rulings...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                } else if case .errored(_, let error) = rulings {
                    ContentUnavailableView {
                        Label("Failed to Load Rulings", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.localizedDescription)
                    } actions: {
                        Button("Try Again", action: onRetry)
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                    }
                } else {
                    ForEach(rulings.latestValue ?? []) { ruling in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(ruling.comment)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)

                            if let date = ruling.publishedAtAsDate {
                                Text(date, format: .dateTime.year().month().day())
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("Rulings")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
        }
        .tint(.primary)
        .padding()
    }
}

// MARK: - Card Other Prints Section

struct CardAllPrintsSection: View {
    let oracleId: String
    let currentCardId: UUID

    @State private var showingPrintsSheet = false

    var body: some View {
        Button {
            showingPrintsSheet = true
        } label: {
            HStack {
                Text("All Prints")
                    .font(.headline)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingPrintsSheet) {
            CardAllPrintsView(oracleId: oracleId, initialCardId: currentCardId)
        }
    }
}
