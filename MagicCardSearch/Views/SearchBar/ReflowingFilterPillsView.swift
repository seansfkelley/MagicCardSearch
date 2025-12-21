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
            //
            // TODO: When deleting earlier pills you can see the X button flying around between
            // pills. I think that means it's reusing the element? If so, presumably because we have
            // the wrong key here.
            alignment: .leading,
            spacing: .constant(8),
            lineSpacing: 8
        ) { index, filter in
            FilterPillView(
                filter: filter,
                onTap: {
                    onFilterEdit(filter)
                    filters.remove(at: index)
                },
                onDelete: {
                    filters.remove(at: index)
                }
            )
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var filters: [SearchFilter] = [
            .init(.keyValue("set", .equal, "7ED")),
            .init(.keyValue("manavalue", .greaterThanOrEqual, "4")),
            .init(.keyValue("power", .greaterThan, "3")),
        ]

        var body: some View {
            VStack {
                ReflowingFilterPillsView(
                    filters: $filters
                ) { filter in
                    print("Editing filter: \(filter.description)")
                }
                Spacer()
            }
        }
    }

    return PreviewWrapper()
}
