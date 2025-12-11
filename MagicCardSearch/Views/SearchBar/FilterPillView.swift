//
//  SearchPillView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI

struct FilterPillView: View {
    let filter: SearchFilter
    let onTap: (() -> Void)?
    let onDelete: (() -> Void)?

    init(filter: SearchFilter, onTap: (() -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self.filter = filter
        self.onTap = onTap
        self.onDelete = onDelete
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Button(action: onTap ?? {}) {
                HStack(spacing: 6) {
                    if !filter.isKnownFilterType {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                    
                    Text(filter.queryStringWithEditingRange.0)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.leading, filter.isKnownFilterType ? 16 : 8)
                .padding(.trailing, onDelete == nil ? 16 : 8)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            if let onDelete = onDelete {
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
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: 32)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}
