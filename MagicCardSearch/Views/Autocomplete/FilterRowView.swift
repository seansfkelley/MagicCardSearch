import SwiftUI

struct FilterRowView: View {
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

                    DebuggableScorableView(scorable: suggestion) {
                        BoldedRangeText(
                            text: match.string,
                            ranges: match.highlights
                        )
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
