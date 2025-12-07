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
    @Binding var unparsedInputText: String
    @FocusState var isSearchFocused: Bool

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
                    unparsedInputText = filter.toIdiomaticString()
                    filters.remove(at: index)
                    isSearchFocused = true
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
        @State private var text = ""
        @FocusState private var isFocused: Bool

        var body: some View {
            VStack {
                ReflowingFilterPillsView(
                    filters: $filters,
                    unparsedInputText: $text,
                    isSearchFocused: _isFocused
                )
                Spacer()
            }
        }
    }

    return PreviewWrapper()
}
