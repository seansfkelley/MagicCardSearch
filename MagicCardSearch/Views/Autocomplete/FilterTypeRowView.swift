import SwiftUI

struct FilterTypeRowView: View {
    @ScaledMetric private var iconWidth = AutocompleteConstants.defaultSuggestionIconWidth

    let suggestion: AutocompleteSuggestion
    let orderedAllComparisons: [Comparison]
    let orderedEqualityComparison: [Comparison]
    let onSelect: (String) -> Void

    var body: some View {
        switch suggestion.content {
        case .filterType(let match):
            HStack(spacing: 12) {
                Image(systemName: suggestion.icon)
                    .foregroundStyle(.secondary)
                    .font(.system(size: suggestion.iconFontSize))
                    .frame(width: iconWidth)

                DebuggableScorableView(scorable: suggestion) {
                    HorizontallyScrollablePillSelector(
                        label: match.string,
                        labelRanges: match.highlights,
                        options: match.value.filterType.comparisonKinds == .all
                        ? orderedAllComparisons
                        : orderedEqualityComparison
                    ) { comparison in
                        onSelect("\(match.string)\(comparison.rawValue)")
                    }
                }
            }
        default:
            EmptyView()
        }
    }
}

private protocol PillSelectorOption {
    associatedtype Value: Hashable

    var value: Value { get }
    var label: String { get }
}

extension Comparison: PillSelectorOption {
    var value: Comparison { self }
    var label: String { rawValue }
}

private struct HorizontallyScrollablePillSelector<T: PillSelectorOption>: View {
    let label: String
    let labelRanges: [Range<String.Index>]
    let options: [T]
    let onTapOption: (T.Value) -> Void

    // TODO: This should be based on the width of the label element.
    private let labelFadeExtent: CGFloat = 50
    @State var labelOpacity: CGFloat = 1

    var body: some View {
        ZStack(alignment: .leading) {
            BoldedRangeText(text: label, ranges: labelRanges)
                .foregroundStyle(.primary)
                .opacity(labelOpacity)
                .padding(.trailing, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    BoldedRangeText(text: label, ranges: labelRanges)
                        .padding(.trailing, 8)
                        .hidden()

                    ForEach(options, id: \.value) { option in
                        Button {
                            onTapOption(option.value)
                        } label: {
                            Text(option.label)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
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
