import SwiftUI

struct ReverseEnumerationRowView: View {
    let suggestion: ReverseEnumerationSuggestion
    let onSelect: (SearchFilter) -> Void
    
    @State private var showingPopover = false

    private var filter: ScryfallFilterType {
        // TODO: Unsafe assertion.
        scryfallFilterByType[suggestion.canonicalFilterName]!
    }

    var body: some View {
        Button {
            onSelect(.basic(
                suggestion.negated,
                suggestion.canonicalFilterName,
                .including,
                suggestion.value
            ))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Text("\(suggestion.negated ? "-" : "")\(suggestion.canonicalFilterName)")
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
                        ComparisonGridPicker(comparisonKinds: filter.comparisonKinds) { comparison in
                            showingPopover = false
                            onSelect(.basic(
                                suggestion.negated,
                                suggestion.canonicalFilterName,
                                comparison,
                                suggestion.value
                            ))
                        }
                        .presentationCompactAdaptation(.popover)
                    }

                    HighlightedText(text: suggestion.value, highlightRange: suggestion.valueMatchRange)
                        .foregroundStyle(.primary)
                    
                    Spacer(minLength: 0)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
