import SwiftUI

struct BasicRowView: View {
    var suggestion: Suggestion
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

                    HighlightedText(
                        text: highlighted.string,
                        highlightRanges: highlighted.highlights
                    )
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        default:
            EmptyView()
        }
    }
}
