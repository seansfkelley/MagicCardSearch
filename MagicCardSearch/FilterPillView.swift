//
//  SearchPillView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI

struct FilterPillView: View {
    let filter: SearchFilter
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onTap) {
                if !isRecognizedFilter {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.red)
                        .padding(12)
                }

                Text(filter.toIdiomaticString())
                    .font(.body)
                    .foregroundStyle(.primary)
                    .padding(.trailing, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)
                .padding(.vertical, 6)

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 36)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: 40)
        .background(Color.gray.opacity(0.2))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var isRecognizedFilter: Bool {
        return switch (filter) {
        case .name: true
        case .keyValue(let key, _, _): configurationForKey(key) != nil
        }
    }
}
