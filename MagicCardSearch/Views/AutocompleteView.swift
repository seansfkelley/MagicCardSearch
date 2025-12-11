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
    let provider: AutocompleteProvider
    let filters: [SearchFilter]
    let onSuggestionTap: (AcceptedSuggestion) -> Void

    private var suggestions: [AutocompleteProvider.Suggestion] {
        // TODO: Cache the set conversion here.
        provider.suggestions(for: inputText, excluding: Set(filters))
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
                                    provider.unpinSearchFilter(suggestion.filter)
                                } else {
                                    provider.pinSearchFilter(suggestion.filter)
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
                                provider.deleteSearchFilter(suggestion.filter)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }

                case .filter(let suggestion):
                    filterTypeRow(suggestion)

                case .enumeration(let suggestion):
                    enumerationRow(suggestion)
                }
            }
        }
        .listStyle(.plain)
    }

    private func historyRow(
        _ suggestion: AutocompleteProvider.HistorySuggestion
    ) -> some View {
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

    private func filterTypeRow(_ suggestion: AutocompleteProvider.FilterTypeSuggestion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                HighlightedText(
                    text: suggestion.filterType,
                    highlightRange: suggestion.matchRange
                )
                
                ComparisonButtonGroup { comparison in
                    onSuggestionTap(.string("\(suggestion.filterType)\(comparison.rawValue)"))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
    
    private func enumerationRow(_ suggestion: AutocompleteProvider.EnumerationSuggestion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "list.bullet.circle")
                .foregroundStyle(.secondary)

            HorizontallyScrollablePillSelector(
                label: "\(suggestion.filterType)\(suggestion.comparison.rawValue)",
                options: suggestion.options as [any PillSelectorOption]
            ) { option in
                    onSuggestionTap(
                        .filter(.basic(.keyValue(suggestion.filterType, suggestion.comparison, option)))
                    )
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Filter Type Picker

private protocol PillSelectorOption {
    var value: String { get }
    var range: Range<String.Index>? { get }
}

extension AutocompleteProvider.EnumerationSuggestion.Option: PillSelectorOption {}

private struct HorizontallyScrollablePillSelector: View {
    let label: String
    let options: [PillSelectorOption]
    let onTapOption: (String) -> Void
    
    // TODO: This should be based on the width of the label element.
    private let labelFadeExtent: CGFloat = 50
    @State var labelOpacity: CGFloat = 1
    
    var body: some View {
        ZStack(alignment: .leading) {
            Text(label)
                .foregroundStyle(.primary)
                .opacity(labelOpacity)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text(label)
                        .hidden()
                    
                    ForEach(options, id: \.value) { option in
                        Button {
                            onTapOption(option.value)
                        } label: {
                            HighlightedText(
                                text: option.value,
                                highlightRange: option.range,
                            )
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                }
            }
            .background(.clear)
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
    let provider = AutocompleteProvider()
    provider.recordFilterUsage(.basic(.keyValue("c", .lessThan, "selesnya")))
    provider.recordFilterUsage(.basic(.keyValue("mv", .greaterThanOrEqual, "10")))
    provider.recordFilterUsage(.basic(.keyValue("set", .including, "mh5")))
    provider.recordFilterUsage(.basic(.name("Lightning Bolt", true)))

    return AutocompleteView(
        inputText: "set",
        provider: provider,
        filters: []
    ) { suggestion in
        print("Selected: \(suggestion)")
    }
}

#Preview("Enumeration Suggestions - Empty") {
    let provider = AutocompleteProvider()
    
    return AutocompleteView(
        inputText: "format:",
        provider: provider,
        filters: []
    ) { suggestion in
        print("Selected: \(suggestion)")
    }
}

#Preview("Enumeration Suggestions - Filtered") {
    let provider = AutocompleteProvider()
    
    return AutocompleteView(
        inputText: "format=m",
        provider: provider,
        filters: []
    ) { suggestion in
        print("Selected: \(suggestion)")
    }
}
