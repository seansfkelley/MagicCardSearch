//
//  FilterPillsView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-06.
//

import SwiftUI
import WrappingHStack

struct ReflowingFilterPillsView: View {
    @Binding var filters: [SearchFilter]
    let onFilterEdit: (SearchFilter) -> Void

    var body: some View {
        WrappingHStack(
            // n.b. you can't use ForEach here as a limitation of the library, so pass the list of
            // things to render to the stack.
            filters.enumerated(),
            // TODO: Does this need `id:` to prevent excessive rendering, or does Swift do value
            // equality such that the enumerated pairs are considered equal?
            alignment: .leading,
            spacing: .constant(8),
            lineSpacing: 8
        ) { index, filter in
            FilterPillView(
                filter: filter,
                onTap: {
                    filters.remove(at: index)
                    onFilterEdit(filter)
                },
                onDelete: {
                    filters.remove(at: index)
                }
            )
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var filters: [SearchFilter] = [
            SearchFilter.keyValue("set", .equal, "7ED"),
            SearchFilter.keyValue("manavalue", .greaterThanOrEqual, "4"),
            SearchFilter.keyValue("power", .greaterThan, "3"),
        ]

        var body: some View {
            VStack {
                ReflowingFilterPillsView(
                    filters: $filters,
                    onFilterEdit: { filter in
                        print("Editing filter: \(filter.toIdiomaticString())")
                    }
                )
                Spacer()
            }
        }
    }

    return PreviewWrapper()
}
