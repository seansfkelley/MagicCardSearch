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
    @Binding var unparsedInputText: String
    @FocusState var isSearchFocused: Bool
    
    var body: some View {
        WrappingHStack(alignment: .leading, spacing: .constant(8), lineSpacing: 8) {
            ForEach(Array(filters.enumerated()), id: \.offset) { index, filter in
                SearchPillView(
                    filter: filter,
                    onTap: {
                        unparsedInputText = filter.idiomaticString
                        filters.remove(at: index)
                        isSearchFocused = true
                    },
                    onDelete: {
                        filters.remove(at: index)
                    }
                )
            }
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
                FilterPillsView(
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
