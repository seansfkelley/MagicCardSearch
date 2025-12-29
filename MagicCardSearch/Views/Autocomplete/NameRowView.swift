//
//  NameRowView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-28.
//
import SwiftUI

private struct NameRowView: View {
    let suggestion: NameSuggestion
    let onTap: (SearchFilter) -> Void
    
    var body: some View {
        Button {
            onTap(suggestion.filter)
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
