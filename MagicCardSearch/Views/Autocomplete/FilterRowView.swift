import SwiftUI

struct FilterRowView: View {
    let suggestion: AutocompleteSuggestion
    let showImmediateSearchIcon: Bool
    let onTap: (FilterQuery<FilterTerm>) -> Void

    var body: some View {
        switch suggestion.content {
        case .filter(var highlighted):
            Button {
                onTap(highlighted.value)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: suggestion.icon)
                        .foregroundStyle(.secondary)

                    DebuggableScorableView(scorable: suggestion) {
                        HighlightedText(
                            text: highlighted.string,
                            highlightRanges: highlighted.highlights
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

