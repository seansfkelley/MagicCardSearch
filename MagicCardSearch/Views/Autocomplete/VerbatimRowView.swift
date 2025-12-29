//
//  VerbatimRowView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-28.
//
import SwiftUI

struct VerbatimRowView: View {
    let filter: SearchFilter
    let onTap: (SearchFilter) -> Void
    
    var body: some View {
        Button {
            onTap(filter)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                Text(filter.description)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
