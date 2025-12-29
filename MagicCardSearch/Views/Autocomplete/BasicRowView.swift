//
//  BasicRowView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-28.
//
import SwiftUI

struct BasicRowView: View {
    let filter: SearchFilter
    let matchRange: Range<String.Index>?
    let systemImageName: String
    let onTap: (SearchFilter) -> Void

    var body: some View {
        Button {
            onTap(filter)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImageName)
                    .foregroundStyle(.secondary)

                HighlightedText(
                    text: filter.description,
                    highlightRange: matchRange
                )
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
