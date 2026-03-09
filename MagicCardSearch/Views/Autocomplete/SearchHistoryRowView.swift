import SwiftUI

struct SearchHistoryRowView: View {
    let suggestion: AutocompleteSuggestion
    let matchedFilter: HighlightedMatch<FilterQuery<FilterTerm>>?
    let otherFilters: [FilterQuery<FilterTerm>]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: suggestion.icon)
                    .foregroundStyle(.secondary)

                DebuggableRowContentView(suggestion: suggestion) {
                    if var highlighted = matchedFilter {
                        HighlightedText(
                            text: highlighted.string + "   " + otherFilters.plaintext,
                            highlightRanges: highlighted.highlights
                        )
                    } else {
                        Text(otherFilters.plaintext)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
