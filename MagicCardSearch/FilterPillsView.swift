//
//  FilterPillsView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-06.
//

import SwiftUI
import WrappingHStack

struct FilterPillsView: View {
    @Binding var filters: [SearchFilter]
    @State private var editingState: EditableItem?
    
    struct EditableItem: Identifiable {
        var id: Int
    }
    
    var body: some View {
        WrappingHStack(alignment: .leading, spacing: .constant(8), lineSpacing: 8) {
            ForEach(Array(filters.enumerated()), id: \.offset) { index, filter in
                SearchPillView(
                    filter: filter,
                    onTap: {
                        editingState = EditableItem(id: index)
                    },
                    onDelete: {
                        filters.remove(at: index)
                    }
                )
            }
        }
        .padding(.horizontal, 16)
        .sheet(item: $editingState) { state in
            EditPillSheet(
                filter: filters[state.id],
                onUpdate: { updatedFilter in
                    filters[state.id] = updatedFilter
                    editingState = nil
                },
                onDelete: {
                    filters.remove(at: state.id)
                    editingState = nil
                }
            )
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var filters: [SearchFilter] = [
            SearchFilter("set", .equal, "7ED"),
            SearchFilter("manavalue", .greaterThanOrEqual, "4"),
            SearchFilter("power", .greaterThan, "3"),
        ]

        var body: some View {
            VStack {
                FilterPillsView(filters: $filters)
                Spacer()
            }
        }
    }

    return PreviewWrapper()
}
