//
//  SearchPillView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI

struct SearchPillView: View {
    let filter: SearchFilter
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressing = false
    @State private var isPressingDelete = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Main pill body
            Text(displayText)
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.leading, 16)
                .padding(.trailing, 12)
                .padding(.vertical, 10)
                .background(isPressing ? Color.gray.opacity(0.3) : Color.clear)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity) {
                    // Never completes
                } onPressingChanged: { pressing in
                    isPressing = pressing
                    if !pressing {
                        onTap()
                    }
                }
            
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)
                .padding(.vertical, 6)
            
            // Delete button (right side with semicircle)
            Image(systemName: "xmark")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 36)
                .frame(maxHeight: .infinity)
                .background(isPressingDelete ? Color.gray.opacity(0.3) : Color.clear)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity) {
                    // Never completes
                } onPressingChanged: { pressing in
                    isPressingDelete = pressing
                    if !pressing {
                        onDelete()
                    }
                }
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: 40)
        .background(pillColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var displayText: String {
        return "\(filter.key)\(filter.comparison.symbol)\(filter.value)"
    }
    
    private var pillColor: Color {
        return Color.gray.opacity(0.2)
    }
}
