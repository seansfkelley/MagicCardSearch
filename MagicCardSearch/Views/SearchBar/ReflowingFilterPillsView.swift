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
