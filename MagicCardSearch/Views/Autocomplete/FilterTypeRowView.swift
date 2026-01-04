import SwiftUI

struct FilterTypeRowView: View {
    let suggestion: FilterTypeSuggestion
    let orderedAllComparisons: [Comparison]
    let orderedEqualityComparison: [Comparison]
    let onSelect: (String) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.secondary)

            HorizontallyScrollablePillSelector(
                label: suggestion.filterType,
                labelRange: suggestion.matchRange,
                options: suggestion.comparisonKinds == .all ? orderedAllComparisons : orderedEqualityComparison
            ) { comparison in
                onSelect("\(suggestion.filterType)\(comparison.rawValue)")
            }
        }
    }
}

private protocol PillSelectorOption {
    associatedtype Value: Hashable

    var value: Value { get }
    var label: String { get }
    var range: Range<String.Index>? { get }
}

extension Comparison: PillSelectorOption {
    var value: Comparison { self }
    var label: String { rawValue }
    var range: Range<String.Index>? { nil }
}

private struct HorizontallyScrollablePillSelector<T: PillSelectorOption>: View {
    let label: String
    let labelRange: Range<String.Index>?
    let options: [T]
    let onTapOption: (T.Value) -> Void

    // TODO: This should be based on the width of the label element.
    private let labelFadeExtent: CGFloat = 50
    @State var labelOpacity: CGFloat = 1

    var body: some View {
        ZStack(alignment: .leading) {
            HighlightedText(text: label, highlightRange: labelRange)
                .foregroundStyle(.primary)
                .opacity(labelOpacity)
                .padding(.trailing, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    HighlightedText(text: label, highlightRange: labelRange)
                        .padding(.trailing, 8)
                        .hidden()

                    ForEach(options, id: \.value) { option in
                        Button {
                            onTapOption(option.value)
                        } label: {
                            HighlightedText(
                                text: option.label,
                                highlightRange: option.range,
                            )
                            .frame(width: 24, height: 24)
                        }
                        .clipShape(Circle())
                        // Unfortunately this makes it slightly transparent, so you can see the
                        // label overlapping the first pills as you scroll over the label.
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                }
            }
            .onScrollGeometryChange(
                for: CGFloat.self,
                of: { geometry in
                    let x = geometry.contentOffset.x
                    return x > labelFadeExtent ? labelFadeExtent : x < 0 ? 0 : x
                },
                action: { _, currentValue in
                    labelOpacity = (labelFadeExtent - currentValue) / labelFadeExtent
                })
            .mask {
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [.clear, .black],
                        startPoint: .leading,
                        endPoint: .trailing,
                    )
                    .frame(width: 20)
                    Rectangle()
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .leading,
                        endPoint: .trailing,
                    )
                    .frame(width: 20)
                }
            }
        }
    }
}
