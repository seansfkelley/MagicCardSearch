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
    let provider: CombinedSuggestionProvider
    let searchHistoryTracker: SearchHistoryTracker
    let filters: [SearchFilter]
    let isSearchFocused: Bool
    let onSuggestionTap: (AcceptedSuggestion) -> Void
    
    @State private var suggestions: [Suggestion] = []
    @State private var nonce: Int = 0
    
    private var searchSuggestionKey: SearchSuggestionKey {
        SearchSuggestionKey(inputText: inputText, filterCount: filters.count, nonce: nonce)
    }
    
    private struct SearchSuggestionKey: Equatable {
        // Obvious.
        let inputText: String
        // This allows the history autocomplete to hide ones you pick. In the future, it might be
        // used for other autocompletes that read your existing filters.
        let filterCount: Int
        // This is a proxy for the value we actually care about: did you perform a search?
        // Performing a search commits all the filters to history, meaning that the history provider
        // now has more options. Instead of watching did-search directly, we just watch for times
        // that the search bar gained focus, which is when we actually need to recalculate.
        //
        // This nonce is also used whenever pinning changes, which can trigger different suggestions.
        let nonce: Int
    }
    
    private let orderedEqualityComparison: [Comparison] = [
        .including,
        .equal,
        .notEqual,
    ]
    
    private let orderedAllComparisons: [Comparison] = [
        .including,
        .equal,
        .lessThan,
        .lessThanOrEqual,
        .greaterThanOrEqual,
        .greaterThan,
        .notEqual,
    ]

    var body: some View {
        List {
            ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                switch suggestion {
                case .pinned(let suggestion):
                    pinnedRow(suggestion)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                provider.pinnedFilterProvider.unpin(filter: suggestion.filter)
                                // If unpinning, keep the filter around in case you want to re-pin it.
                                searchHistoryTracker.recordUsage(of: suggestion.filter)
                                nonce += 1
                            } label: {
                                Label("Unpin", systemImage: "pin.slash")
                            }
                            .tint(.orange)
                        }
                        .listRowInsets(.vertical, 0)
                case .history(let suggestion):
                    historyRow(suggestion)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            pinSwipeAction(for: suggestion.filter)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                searchHistoryTracker.delete(filter: suggestion.filter)
                                nonce += 1
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowInsets(.vertical, 0)

                case .filter(let suggestion):
                    filterTypeRow(suggestion)
                        .listRowInsets(.vertical, 0)

                case .enumeration(let suggestion):
                    enumerationRows(suggestion)
                        .listRowInsets(.vertical, 0)
                
                case .name(let suggestion):
                    nameRow(suggestion)
                        .listRowInsets(.vertical, 0)
                }
            }
        }
        .listStyle(.plain)
        .task(id: searchSuggestionKey) {
            for await newSuggestions in provider.getSuggestions(for: inputText, existingFilters: Set(filters)) {
                suggestions = newSuggestions
            }
        }
        .onChange(of: isSearchFocused) { wasFocused, isFocused in
            if !wasFocused && isFocused {
                nonce += 1
            }
        }
    }
    
    @ViewBuilder
    private func pinSwipeAction(for filter: SearchFilter) -> some View {
        Button {
            provider.pinnedFilterProvider.pin(filter: filter)
            nonce += 1
        } label: {
            Label("Pin", systemImage: "pin")
        }
        .tint(.orange)
    }
    
    private func pinnedRow(_ suggestion: PinnedFilterSuggestion) -> some View {
        let filterString = suggestion.filter.queryStringWithEditingRange.0
        return Button {
            onSuggestionTap(.filter(suggestion.filter))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.secondary)
                HighlightedText(
                    text: filterString,
                    highlightRange: suggestion.matchRange
                )
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                options: suggestion.comparisonKinds == .all ? orderedAllComparisons : orderedEqualityComparison,
            ) { comparison in
                onSuggestionTap(.string("\(suggestion.filterType)\(comparison.rawValue)"))
            }
        }
    }
    
    private func enumerationRows(_ suggestion: EnumerationSuggestion) -> some View {
        ForEach(suggestion.options, id: \.value) { option in
            let filterContent = SearchFilterContent.keyValue(suggestion.filterType, suggestion.comparison, option.value)
            let filter: SearchFilter = suggestion.isNegated ? .negated(filterContent) : .basic(filterContent)
            
            Button {
                onSuggestionTap(.filter(filter))
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "list.bullet.circle")
                        .foregroundStyle(.secondary)
                    
                    let prefix = "\(suggestion.isNegated ? "-" : "")\(suggestion.filterType)\(suggestion.comparison.rawValue)"
                    let formattedOption = "\(prefix)\(option.value)"
                    
                    HighlightedText(
                        text: formattedOption,
                        highlightRange: option.range.map { $0.offset(with: formattedOption, by: prefix.count) },
                    )
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                pinSwipeAction(for: filter)
            }
        }
    }
    
    private func nameRow(_ suggestion: NameSuggestion) -> some View {
        Button {
            if let filter = SearchFilter.tryParseUnambiguous(suggestion.filterText) {
                onSuggestionTap(.filter(filter))
            } else {
                // TODO: Real logging infrastructure.
                print("Warning: Failed to parse name suggestion as unambiguous filter: \(suggestion.filterText)")
                onSuggestionTap(.string(suggestion.filterText))
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "textformat.abc")
                    .foregroundStyle(.secondary)
                
                HighlightedText(
                    text: suggestion.filterText,
                    highlightRange: suggestion.matchRange
                )
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
