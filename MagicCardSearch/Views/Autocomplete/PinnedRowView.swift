//
//  PinnedRowView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-28.
//
import SwiftUI

struct PinnedRowView: View {
    let suggestion: PinnedFilterSuggestion
    let onTap: (SearchFilter) -> Void
    
    var body: some View {
        Button {
            onTap(suggestion.filter)
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
}
