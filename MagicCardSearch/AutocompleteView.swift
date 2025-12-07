//
//  AutocompleteView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import SwiftUI

struct AutocompleteView: View {
    let inputText: String
    let onSuggestionTap: (String) -> Void

    // Hardcoded suggestions for now
    private let suggestions = [
        "c<selesnya",
        "mv>=10",
        "set:mh5",
    ]

    var body: some View {
        List {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    onSuggestionTap(suggestion)
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    Text(suggestion)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    AutocompleteView(inputText: "c") { suggestion in
        print("Selected: \(suggestion)")
    }
}
