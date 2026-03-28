import SwiftUI

struct FilterRowView: View {
    @ScaledMetric private var iconWidth = AutocompleteConstants.defaultSuggestionIconWidth

    let suggestion: AutocompleteSuggestion
    let showImmediateSearchIcon: Bool
    let onTap: (FilterQuery<FilterTerm>) -> Void

    var body: some View {
        switch suggestion.content {
        case .filter(let match):
            Button {
                onTap(match.value)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: suggestion.icon)
                        .foregroundStyle(.secondary)
                        .font(.system(size: suggestion.iconFontSize))
                        .frame(width: iconWidth)

                    DebuggableScorableView(scorable: suggestion) {
                        Text(match.string.attributed(in: match.highlights))
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .foregroundStyle(.primary)
                    }

                    Spacer(minLength: 0)

                    if showImmediateSearchIcon {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        default:
            EmptyView()
        }
    }
}
