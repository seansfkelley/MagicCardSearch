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

    private var suggestions: [String] {
        historyProvider.searchHistory(prefix: inputText)
    }

    var body: some View {
        List {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    onSuggestionTap(suggestion)
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        Text(suggestion)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    let provider = FilterHistoryProvider()
    // Add some sample filters to the provider
    provider.recordFilter(SearchFilter.keyValue("c", .lessThan, "selesnya"))
    provider.recordFilter(SearchFilter.keyValue("mv", .greaterThanOrEqual, "10"))
    provider.recordFilter(SearchFilter.keyValue("set", .including, "mh5"))
    
    return AutocompleteView(
        inputText: "c",
        historyProvider: provider
    ) { suggestion in
        print("Selected: \(suggestion)")
    }
}
