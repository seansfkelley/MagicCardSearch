//
//  AutocompleteView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import SwiftUI

struct AutocompleteView: View {
    enum AcceptedSuggestion {
        case filter(SearchFilter)
        case string(String)
    }

    let inputText: String
    let provider: SuggestionMuxer
    let filters: [SearchFilter]
    let onSuggestionTap: (AcceptedSuggestion) -> Void
    
    private let orderedComparisons: [Comparison] = [
        .including,
        .equal,
        .lessThan,
        .lessThanOrEqual,
        .greaterThanOrEqual,
        .greaterThan,
        .notEqual,
    ]

    private var suggestions: [Suggestion] {
        // TODO: Convert filters to a set and cache it.
        provider.getSuggestions(inputText, existingFilters: filters)
    }

    var body: some View {
        List {
            ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                switch suggestion {
                case .history(let suggestion):
                    historyRow(suggestion)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                if suggestion.isPinned {
                                    provider.historyProvider.unpinSearchFilter(suggestion.filter)
                                } else {
                                    provider.historyProvider.pinSearchFilter(suggestion.filter)
                                }
                            } label: {
                                if suggestion.isPinned {
                                    Label("Unpin", systemImage: "pin.slash")
                                } else {
                                    Label("Pin", systemImage: "pin")
                                }
                            }
                            .tint(.orange)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                provider.historyProvider.deleteSearchFilter(suggestion.filter)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowInsets(.vertical, 0)

                case .filter(let suggestion):
                    filterTypeRow(suggestion)
                        .listRowInsets(.vertical, 0)

                case .enumeration(let suggestion):
                    enumerationRow(suggestion)
                        .listRowInsets(.vertical, 0)
                }
            }
        }
        .listStyle(.plain)
    }

    private func historyRow(_ suggestion: HistorySuggestion) -> some View {
        let filterString = suggestion.filter.queryStringWithEditingRange.0
        return Button {
            onSuggestionTap(.filter(suggestion.filter))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                HighlightedText(
                    text: filterString,
                    highlightRange: suggestion.matchRange
                )
                Spacer(minLength: 0)

                if suggestion.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func filterTypeRow(_ suggestion: FilterTypeSuggestion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.secondary)

            HorizontallyScrollablePillSelector(
                label: suggestion.filterType,
                labelRange: suggestion.matchRange,
                options: orderedComparisons,
            ) { comparison in
                onSuggestionTap(.string("\(suggestion.filterType)\(comparison.rawValue)"))
            }
        }
    }
    
    private func enumerationRow(_ suggestion: EnumerationSuggestion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "list.bullet.circle")
                .foregroundStyle(.secondary)

            HorizontallyScrollablePillSelector(
                label: "\(suggestion.filterType)\(suggestion.comparison.rawValue)",
                labelRange: nil,
                options: suggestion.options
            ) { option in
                    onSuggestionTap(
                        .filter(.basic(.keyValue(suggestion.filterType, suggestion.comparison, option)))
                    )
            }
        }
    }
}

// MARK: - Filter Type Picker

private protocol PillSelectorOption {
    associatedtype Value: Hashable
    
    var value: Value { get }
    var label: String { get }
    var range: Range<String.Index>? { get }
}

extension EnumerationSuggestion.Option: PillSelectorOption {
    var label: String { value }
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
                            .frame(minWidth: 30)
                        }
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

extension Comparison: PillSelectorOption {
    var value: Comparison { self }
    var label: String { rawValue }
    var range: Range<String.Index>? { nil }
}

// MARK: - Highlighted Text View

struct HighlightedText: View {
    let text: String
    let highlightRange: Range<String.Index>?

    var body: some View {
        if let range = highlightRange {
            Text(buildAttributedString(text: text, highlightRange: range))
                .foregroundStyle(.primary)
        } else {
            Text(text)
                .foregroundStyle(.primary)
        }
    }

    private func buildAttributedString(text: String, highlightRange: Range<String.Index>)
        -> AttributedString {
        var attributedString = AttributedString(text)

        // Convert String.Index range to AttributedString.Index range
        let startOffset = text.distance(from: text.startIndex, to: highlightRange.lowerBound)
        let endOffset = text.distance(from: text.startIndex, to: highlightRange.upperBound)

        let attrStart = attributedString.index(
            attributedString.startIndex,
            offsetByCharacters: startOffset
        )
        let attrEnd = attributedString.index(
            attributedString.startIndex,
            offsetByCharacters: endOffset
        )

        let attrRange = attrStart..<attrEnd
        attributedString[attrRange].font = .body.bold()

        return attributedString
    }
}

// MARK: - Preview

#Preview("Filter Type Suggestions") {
    AutocompleteView(
        inputText: "set",
        provider: SuggestionMuxer(
            historyProvider: HistorySuggestionProvider(),
            filterProvider: FilterTypeSuggestionProvider(),
            enumerationProvider: EnumerationSuggestionProvider(),
        ),
        filters: [],
    ) { suggestion in
        print("Selected: \(suggestion)")
    }
}

#Preview("Enumeration Suggestions - Empty") {
    AutocompleteView(
        inputText: "format:",
        provider: SuggestionMuxer(
            historyProvider: HistorySuggestionProvider(),
            filterProvider: FilterTypeSuggestionProvider(),
            enumerationProvider: EnumerationSuggestionProvider(),
        ),
        filters: [],
    ) { suggestion in
        print("Selected: \(suggestion)")
    }
}

#Preview("Enumeration Suggestions - Filtered") {
    AutocompleteView(
        inputText: "format=m",
        provider: SuggestionMuxer(
            historyProvider: HistorySuggestionProvider(),
            filterProvider: FilterTypeSuggestionProvider(),
            enumerationProvider: EnumerationSuggestionProvider(),
        ),
        filters: [],
    ) { suggestion in
        print("Selected: \(suggestion)")
    }
}
