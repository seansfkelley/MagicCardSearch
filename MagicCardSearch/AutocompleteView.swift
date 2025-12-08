//
//  AutocompleteView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import SwiftUI

struct AutocompleteView: View {
    let inputText: String
    let historyProvider: FilterHistoryProvider
    let onSuggestionTap: (String) -> Void

    private var suggestions: [(filterString: String, matchRange: Range<String.Index>?)] {
        historyProvider.searchHistory(prefix: inputText)
    }

    var body: some View {
        List {
            ForEach(suggestions, id: \.filterString) { suggestion in
                Button {
                    onSuggestionTap(suggestion.filterString)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        HighlightedText(
                            text: suggestion.filterString,
                            highlightRange: suggestion.matchRange
                        )
                        Spacer(minLength: 0)
                        
                        if historyProvider.isPinned(suggestion.filterString) {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        historyProvider.togglePin(suggestion.filterString)
                    } label: {
                        if historyProvider.isPinned(suggestion.filterString) {
                            Label("Unpin", systemImage: "pin.slash")
                        } else {
                            Label("Pin", systemImage: "pin")
                        }
                    }
                    .tint(.orange)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        historyProvider.deleteFilter(suggestion.filterString)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
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

#Preview {
    let provider = FilterHistoryProvider()
    // Add some sample filters to the provider
    provider.recordFilter(SearchFilter.keyValue("c", .lessThan, "selesnya"))
    provider.recordFilter(SearchFilter.keyValue("mv", .greaterThanOrEqual, "10"))
    provider.recordFilter(SearchFilter.keyValue("set", .including, "mh5"))
    provider.recordFilter(SearchFilter.name("Lightning Bolt"))

    return AutocompleteView(
        inputText: "set",
        historyProvider: provider
    ) { suggestion in
        print("Selected: \(suggestion)")
    }
}
