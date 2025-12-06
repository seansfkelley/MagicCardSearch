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
            HStack(spacing: 6) {
                if !isRecognizedFilter {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.red)
                }
                
                Text(displayText)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
            .background(isPressing ? Color.gray.opacity(0.3) : Color.clear)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity) {
            } onPressingChanged: { pressing in
                isPressing = pressing
                if !pressing {
                    onTap()
                }
            }
            
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
    
    private var isRecognizedFilter: Bool {
        return configurationForKey(filter.key) != nil
    }
}
