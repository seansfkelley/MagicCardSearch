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
    let suggestionProvider: AutocompleteProvider
    let filters: [SearchFilter]
    let onSuggestionTap: (AcceptedSuggestion) -> Void

    private var suggestions: [AutocompleteProvider.Suggestion] {
        // TODO: Cache the set conversion here.
        suggestionProvider.suggestions(for: inputText, excluding: Set(filters))
    }

    var body: some View {
        List {
            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                suggestionRow(for: suggestion, at: index)
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func suggestionRow(for suggestion: AutocompleteProvider.Suggestion, at index: Int)
        -> some View
    {
        switch suggestion {
        case .history(let historySuggestion):
            historyRow(historySuggestion: historySuggestion)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        if historySuggestion.isPinned {
                            suggestionProvider.unpinSearchFilter(historySuggestion.filter)
                        } else {
                            suggestionProvider.pinSearchFilter(historySuggestion.filter)
                        }
                    } label: {
                        if historySuggestion.isPinned {
                            Label("Unpin", systemImage: "pin.slash")
                        } else {
                            Label("Pin", systemImage: "pin")
                        }
                    }
                    .tint(.orange)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        let entry = AutocompleteProvider.HistoryEntry(
                            filter: historySuggestion.filter,
                            timestamp: Date(),
                            isPinned: historySuggestion.isPinned
                        )
                        suggestionProvider.deleteHistoryEntry(entry)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

        case .filter(let filterTypeSuggestion):
            filterTypeRow(filterTypeSuggestion: filterTypeSuggestion)

        case .enumeration(let enumerationSuggestion):
            enumerationRow(enumerationSuggestion: enumerationSuggestion)
        }
    }

    private func historyRow(
        historySuggestion: AutocompleteProvider.HistorySuggestion
    ) -> some View {
        let filterString = historySuggestion.filter.queryStringWithEditingRange.0
        return Button {
            onSuggestionTap(.filter(historySuggestion.filter))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                HighlightedText(
                    text: filterString,
                    highlightRange: historySuggestion.matchRange
                )
                Spacer(minLength: 0)

                if historySuggestion.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func filterTypeRow(filterTypeSuggestion: AutocompleteProvider.FilterTypeSuggestion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                HighlightedText(
                    text: filterTypeSuggestion.filterType,
                    highlightRange: filterTypeSuggestion.matchRange
                )
                
                ComparisonButtonGroup(onButtonTap: { comparison in
                    onSuggestionTap(.string("\(filterTypeSuggestion.filterType)\(comparison.rawValue)"))
                })
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
    
    private func enumerationRow(enumerationSuggestion: AutocompleteProvider.EnumerationSuggestion) -> some View {
        // Convert the dictionary back to an array of tuples for display
        let options = Array(enumerationSuggestion.options.map { ($0.key, $0.value) })
            .sorted { $0.0.count < $1.0.count } // Sort by length
        
        return HStack(spacing: 12) {
            Image(systemName: "list.bullet.circle")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(enumerationSuggestion.filterType)\(enumerationSuggestion.comparison.rawValue)")
                    .foregroundStyle(.primary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    EnumerationButtonGroup(
                        options: options,
                        onButtonTap: { option in
                            onSuggestionTap(.string("\(enumerationSuggestion.filterType)\(enumerationSuggestion.comparison.rawValue)\(option)"))
                        }
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Filter Type Picker

private struct EnumerationButtonGroup: View {
    let options: [(String, Range<String.Index>?)]
    let onButtonTap: (String) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, item in
                let (option, matchRange) = item
                Button {
                    onButtonTap(option)
                } label: {
                    HighlightedText(
                        text: option,
                        highlightRange: matchRange
                    )
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 2)
    }
}

private struct ComparisonButtonGroup: View {
    let onButtonTap: (Comparison) -> Void
    
    private let orderedComparisons: [Comparison] = [
        .including,
        .equal,
        .notEqual,
        .lessThan,
        .lessThanOrEqual,
        .greaterThan,
        .greaterThanOrEqual,
    ]
    
    var body: some View {
        HStack {
            ForEach(Array(orderedComparisons.enumerated()), id: \.offset) { _, option in
                Button {
                    onButtonTap(option)
                } label: {
                    Text(option.rawValue)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 0)
            }
        }
    }
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
        -> AttributedString
    {
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
    let provider = AutocompleteProvider()
    provider.recordFilterUsage(SearchFilter.keyValue("c", .lessThan, "selesnya"))
    provider.recordFilterUsage(SearchFilter.keyValue("mv", .greaterThanOrEqual, "10"))
    provider.recordFilterUsage(SearchFilter.keyValue("set", .including, "mh5"))
    provider.recordFilterUsage(SearchFilter.name("Lightning Bolt"))

    return AutocompleteView(
        inputText: "set",
        suggestionProvider: provider,
        filters: []
    ) { suggestion in
        print("Selected: \(suggestion)")
    }
}

#Preview("Enumeration Suggestions - Empty") {
    let provider = AutocompleteProvider()
    
    return AutocompleteView(
        inputText: "format:",
        suggestionProvider: provider,
        filters: []
    ) { suggestion in
        print("Selected: \(suggestion)")
    }
}

#Preview("Enumeration Suggestions - Filtered") {
    let provider = AutocompleteProvider()
    
    return AutocompleteView(
        inputText: "rarity=my",
        suggestionProvider: provider,
        filters: []
    ) { suggestion in
        print("Selected: \(suggestion)")
    }
}
