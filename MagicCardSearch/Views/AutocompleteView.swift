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

    let allText: String
    let filterText: String
    let provider: CombinedSuggestionProvider
    let searchHistoryTracker: SearchHistoryTracker
    let filters: [SearchFilter]
    let onSuggestionTap: (AcceptedSuggestion) -> Void
    
    @State private var suggestions: [Suggestion] = []
    @State private var nonce: Int = 0
    
    private var searchSuggestionKey: SearchSuggestionKey {
        SearchSuggestionKey(inputText: filterText, filterCount: filters.count, nonce: nonce)
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
    ]
    
    private let orderedAllComparisons: [Comparison] = [
        .including,
        .equal,
        .lessThan,
        .lessThanOrEqual,
        .greaterThanOrEqual,
        .greaterThan,
        .notEqual, // n.b. this only works for some orderable things; equality-only things require the negation syntax
    ]

    var body: some View {
        List {
            if let filter = allText.toSearchFilter().value {
                verbatimRow(filter)
            }

            ForEach(suggestions, id: \.self) { suggestion in
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
                                searchHistoryTracker.deleteUsage(of: suggestion.filter)
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
                    enumerationRow(suggestion)
                        .listRowInsets(.vertical, 0)
                
                case .reverseEnumeration(let suggestion):
                    reverseEnumerationRow(suggestion)
                        .listRowInsets(.vertical, 0)
                
                case .name(let suggestion):
                    nameRow(suggestion)
                        .listRowInsets(.vertical, 0)
                }
            }
        }
        .listStyle(.plain)
        .task(id: searchSuggestionKey) {
            for await newSuggestions in provider.getSuggestions(for: filterText, existingFilters: Set(filters)) {
                suggestions = newSuggestions
            }
        }
    }
    
    @ViewBuilder
    private func verbatimRow(_ filter: SearchFilter) -> some View {
        Button {
            onSuggestionTap(.filter(filter))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                Text(filter.description)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(.vertical, 0)
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
        return Button {
            onSuggestionTap(.filter(suggestion.filter))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.secondary)
                HighlightedText(
                    text: suggestion.filter.description,
                    highlightRange: suggestion.matchRange
                )
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func historyRow(_ suggestion: HistorySuggestion) -> some View {
        return Button {
            onSuggestionTap(.filter(suggestion.filter))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                HighlightedText(
                    text: suggestion.filter.description,
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
    
    private func enumerationRow(_ suggestion: EnumerationSuggestion) -> some View {
        Button {
            onSuggestionTap(.filter(suggestion.filter))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "list.bullet.circle")
                    .foregroundStyle(.secondary)
                HighlightedText(
                    text: suggestion.filter.description,
                    highlightRange: suggestion.matchRange,
                )
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            pinSwipeAction(for: suggestion.filter)
        }
    }
    
    private func reverseEnumerationRow(_ suggestion: ReverseEnumerationSuggestion) -> some View {
        ReverseEnumerationRowView(
            suggestion: suggestion,
            onSuggestionTap: onSuggestionTap
        )
    }
    
    private func nameRow(_ suggestion: NameSuggestion) -> some View {
        Button {
            onSuggestionTap(.filter(suggestion.filter))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "textformat.abc")
                    .foregroundStyle(.secondary)
                
                HighlightedText(
                    text: suggestion.filter.description,
                    highlightRange: suggestion.matchRange
                )
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reverse Enumeration Row

private struct ReverseEnumerationRowView: View {
    let suggestion: ReverseEnumerationSuggestion
    let onSuggestionTap: (AutocompleteView.AcceptedSuggestion) -> Void
    
    @State private var showingPopover = false

    private var filter: ScryfallFilterType {
        // TODO: Unsafe assertion.
        scryfallFilterByType[suggestion.canonicalFilterName]!
    }

    var body: some View {
        Button {
            onSuggestionTap(.filter(.basic(
                suggestion.negated,
                suggestion.canonicalFilterName,
                .including,
                suggestion.value
            )))
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
                            onSuggestionTap(.filter(.basic(
                                suggestion.negated,
                                suggestion.canonicalFilterName,
                                comparison,
                                suggestion.value
                            )))
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

// MARK: - Comparison Grid Picker

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

// MARK: - Filter Type Picker

private protocol PillSelectorOption {
    associatedtype Value: Hashable
    
    var value: Value { get }
    var label: String { get }
    var range: Range<String.Index>? { get }
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

extension Comparison: PillSelectorOption {
    var value: Comparison { self }
    var label: String { rawValue }
    var range: Range<String.Index>? { nil }
}

// MARK: - Highlighted Text View

private struct HighlightedText: View {
    let text: String
    let highlightRange: Range<String.Index>?

    var body: some View {
        if let range = highlightRange {
            Text(buildAttributedString(text: text, highlightRange: range))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        } else {
            Text(text)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
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
