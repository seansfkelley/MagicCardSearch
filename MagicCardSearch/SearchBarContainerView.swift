//
//  SearchBarContainerView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-06.
//

import SwiftUI

struct SearchBarContainerView: View {
    @Binding var filters: [SearchFilter]
    @Binding var unparsedInputText: String
    @FocusState var isSearchFocused: Bool
    let onFilterSetTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                
                if !filters.isEmpty {
                    Button(action: {
                        filters.removeAll()
                    }) {
                        Text("Clear All")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            if !filters.isEmpty {
                FilterPillsView(filters: $filters)
            }

            SearchBarView(
                filters: $filters,
                unparsedInputText: $unparsedInputText,
                isSearchFocused: _isSearchFocused
            )
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
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
        @State private var text = ""
        @FocusState private var isFocused: Bool

        var body: some View {
            VStack {
                Spacer()
                SearchBarContainerView(
                    filters: $filters,
                    unparsedInputText: $text,
                    isSearchFocused: _isFocused,
                    onFilterSetTap: { print("Filter set tapped") }
                )
            }
        }
    }

    return PreviewWrapper()
}
