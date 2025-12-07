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
    @State private var showFilterPopover = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
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
                FilterPillsView(
                    filters: $filters,
                    unparsedInputText: $unparsedInputText,
                    isSearchFocused: _isSearchFocused
                )
            }

            HStack {
                Button(action: {
                    showFilterPopover = true
                }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(.primary)
                }
                .popover(isPresented: $showFilterPopover, arrowEdge: .bottom) {
                    FilterQuickAddMenu()
                        .presentationCompactAdaptation(.popover)
                }
                
                SearchBarView(
                    filters: $filters,
                    unparsedInputText: $unparsedInputText,
                    isSearchFocused: _isSearchFocused
                )
            }
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Filter Quick Add Menu

struct FilterQuickAddMenu: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FilterQuickAddItem(title: "Color", icon: "circle.lefthalf.filled")
            Divider()
            FilterQuickAddItem(title: "Mana Value", icon: "drop.fill")
            Divider()
            FilterQuickAddItem(title: "Type", icon: "doc.text")
            Divider()
            FilterQuickAddItem(title: "Set", icon: "shippingbox")
            Divider()
            FilterQuickAddItem(title: "Rarity", icon: "star.fill")
            Divider()
            FilterQuickAddItem(title: "Power/Toughness", icon: "shield.fill")
        }
        .frame(width: 200)
    }
}

struct FilterQuickAddItem: View {
    let title: String
    let icon: String
    
    var body: some View {
        Button(action: {
            print("Selected: \(title)")
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
