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
        case .history(let entry, let matchRange):
            historyRow(entry: entry, matchRange: matchRange)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        if entry.isPinned {
                            suggestionProvider.unpinHistoryEntry(entry)
                        } else {
                            suggestionProvider.pinHistoryEntry(entry)
                        }
                    } label: {
                        if entry.isPinned {
                            Label("Unpin", systemImage: "pin.slash")
                        } else {
                            Label("Pin", systemImage: "pin")
                        }
                    }
                    .tint(.orange)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        suggestionProvider.deleteHistoryEntry(entry)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

        case .filterType(let filterType, let matchRange):
            filterTypeRow(filterType: filterType, matchRange: matchRange)

        case .enumeration(let options):
            Group {}
        }
    }

    private func historyRow(
        entry: AutocompleteProvider.HistoryEntry,
        matchRange: Range<String.Index>?
    ) -> some View {
        let filterString = entry.filter.queryStringWithEditingRange.0
        return Button {
            onSuggestionTap(.filter(entry.filter))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                HighlightedText(
                    text: filterString,
                    highlightRange: matchRange
                )
                Spacer(minLength: 0)

                if entry.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func filterTypeRow(filterType: String, matchRange: Range<String.Index>?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                HighlightedText(
                    text: filterType,
                    highlightRange: matchRange
                )
                
                ComparisonButtonGroup(onButtonTap: { comparison in
                    onSuggestionTap(.string("\(filterType)\(comparison.rawValue)"))
                })
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Filter Type Picker

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

#Preview {
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
