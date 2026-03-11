import SwiftUI
import ScryfallKit

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
