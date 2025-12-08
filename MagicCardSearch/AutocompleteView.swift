//
//  AutocompleteView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import SwiftUI

struct AutocompleteView: View {
    enum AcceptedSuggestion {
        case .filter(SearchFilter)
        case .string(String)
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
            ForEach(suggestions) { suggestion in
                Button {
                    onSuggestionTap(switch suggestion {
                    case .history(let entry, _):
                        entry.filter.queryStringWithEditingRange.0
                    case .filterType(let s, _):
                        s
                    case .
                    })
                    onSuggestionTap(suggestion)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        HighlightedText(
                            text: suggestion.filterString,
                            highlightRange: suggestion.matchRange
                        )
                        Spacer(minLength: 0)
                        
                        if suggestion.entry.isPinned {
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
                        if suggestion.entry.isPinned {
                            historyProvider.unpinHistoryEntry(suggestion.entry)
                        } else {
                            historyProvider.pinHistoryEntry(suggestion.entry)
                        }
                    } label: {
                        if suggestion.entry.isPinned {
                            Label("Unpin", systemImage: "pin.slash")
                        } else {
                            Label("Pin", systemImage: "pin")
                        }
                    }
                    .tint(.orange)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        historyProvider.deleteHistoryEntry(suggestion.entry)
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
    let provider = AutocompleteProvider()
    provider.recordFilter(SearchFilter.keyValue("c", .lessThan, "selesnya"))
    provider.recordFilter(SearchFilter.keyValue("mv", .greaterThanOrEqual, "10"))
    provider.recordFilter(SearchFilter.keyValue("set", .including, "mh5"))
    provider.recordFilter(SearchFilter.name("Lightning Bolt"))

    return AutocompleteView(
        inputText: "set",
        suggestionProvider: provider,
        filters: []
    ) { suggestion in
        print("Selected: \(suggestion)")
    }
}
