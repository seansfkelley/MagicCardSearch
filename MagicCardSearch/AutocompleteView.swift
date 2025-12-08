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
    private func suggestionRow(for suggestion: AutocompleteProvider.Suggestion, at index: Int) -> some View {
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
            
        case .comparison(let comparisons):
            comparisonRow(comparisons: comparisons)
            
        case .enumeration(let options):
            enumerationRow(options: options)
        }
    }
    
    private func historyRow(entry: AutocompleteProvider.HistoryEntry, matchRange: Range<String.Index>?) -> some View {
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
        Button {
            onSuggestionTap(.string(filterType))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(.secondary)
                HighlightedText(
                    text: filterType,
                    highlightRange: matchRange
                )
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func comparisonRow(comparisons: [Comparison: Range<String.Index>]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "equal.circle")
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(inputText)
                    .foregroundStyle(.primary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([Comparison.including, .equal, .notEqual, .lessThan, .lessThanOrEqual, .greaterThan, .greaterThanOrEqual], id: \.self) { comparison in
                            Button {
                                onSuggestionTap(.string(inputText + comparison.symbol))
                            } label: {
                                Text(comparison.symbol)
                                    .font(.body.monospaced())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor.opacity(0.15))
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
    
    private func enumerationRow(options: [(String, Range<String.Index>?)]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "list.bullet.circle")
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(inputText)
                    .foregroundStyle(.primary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                            Button {
                                onSuggestionTap(.string(inputText + option.0))
                            } label: {
                                if let range = option.1 {
                                    HighlightedText(
                                        text: option.0,
                                        highlightRange: range
                                    )
                                    .font(.body)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Text(option.0)
                                        .font(.body)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.accentColor.opacity(0.15))
                                        .foregroundStyle(.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
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
