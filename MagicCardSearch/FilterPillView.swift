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
                HStack(spacing: 6) {
                    if !isRecognizedFilter {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                    
                    Text(filter.queryStringWithEditingRange.0)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.leading)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            Divider()
                .frame(height: 20)
            
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                    .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: 32)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
    
    private var isRecognizedFilter: Bool {
        return switch (filter) {
        case .name: true
        case .keyValue(let key, _, _): configurationForKey(key) != nil
        }
    }
}
