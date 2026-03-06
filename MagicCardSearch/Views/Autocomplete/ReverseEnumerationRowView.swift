import SwiftUI

struct FilterPartsRowView: View {
    var suggestion: Suggestion
    let onSelect: (FilterTerm) -> Void

    @State private var showingPopover = false

    var body: some View {
        switch suggestion.content {
        case .filterParts(let polarity, let filterType, var highlighted):
            let value = highlighted.value
            Button {
                onSelect(.basic(polarity, filterType.canonicalName, .including, value))
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: suggestion.icon)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Text("\(polarity.description)\(filterType.canonicalName)")
                            .foregroundStyle(.primary)

                        Button {
                            showingPopover = true
                        } label: {
                            Text(":")
                                .foregroundStyle(.primary)

                            Divider()

                            Image(systemName: "chevron.up.chevron.down")
                                .imageScale(.small)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        .fixedSize()
                        .popover(isPresented: $showingPopover) {
                            ComparisonGridPicker(comparisonKinds: filterType.comparisonKinds) { comparison in
                                showingPopover = false
                                onSelect(.basic(polarity, filterType.canonicalName, comparison, value))
                            }
                            .presentationCompactAdaptation(.popover)
                        }

                        HighlightedText(text: highlighted.string, highlightRanges: highlighted.highlights)
                            .foregroundStyle(.primary)

                        Spacer(minLength: 0)
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

private struct ComparisonGridPicker: View {
    let comparisonKinds: ScryfallFilterType.ComparisonKinds
    let onSelect: (Comparison) -> Void

    private var groupedComparisons: [[Comparison]] {
        switch comparisonKinds {
        case .equality:
            return [[.including], [.equal]]
        case .all:
            return [
                [.including],
                [.equal, .notEqual],
                [.lessThanOrEqual, .greaterThanOrEqual],
                [.lessThan, .greaterThan],
            ]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(groupedComparisons, id: \.self) { comparisons in
                HStack(spacing: 0) {
                    ForEach(comparisons, id: \.self) { comparison in
                        Button {
                            onSelect(comparison)
                        } label: {
                            Text(comparison.rawValue)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        .clipShape(Capsule())
                        .padding(4)
                    }
                }
            }
        }
        .padding(8)
        .frame(minWidth: comparisonKinds == .all ? 180 : 100)
    }
}
