//
//  SearchBarContainerView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-06.
//

import SwiftUI

struct BottomBarFilterView: View {
    @Binding var filters: [SearchFilter]
    @Binding var inputText: String
    @FocusState var isSearchFocused: Bool
    let onFilterSetTap: () -> Void

    @State private var inputSelection: TextSelection?
    @State private var showFilterPopover = false
    @State private var pendingSelection: TextSelection?

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
                ReflowingFilterPillsView(
                    filters: $filters,
                    onFilterEdit: { filter in
                        let (prefix, highlightable, suffix) = filter.toResettableParts()
                        inputText = "\(prefix)\(highlightable)\(suffix)"
                        
                        // TODO: This is horrible. What is the right way to do this?
                        let tmp = "\(prefix)\(highlightable)"
                        let selection = TextSelection(range: prefix.endIndex..<tmp.endIndex)

                        // Unfortunate, but seems to be the only way that we can reliably focus the
                        // text whether or not the text field is currently focused.
                        if isSearchFocused {
                            inputSelection = selection
                        } else {
                            pendingSelection = selection
                            isSearchFocused = true
                        }
                    }
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
                    inputText: $inputText,
                    inputSelection: $inputSelection,
                    isSearchFocused: _isSearchFocused,
                )
            }
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .onChange(of: isSearchFocused, { _, _ in
            if let s = pendingSelection {
                inputSelection = s
                pendingSelection = nil
            }
        })
        .onChange(of: filters.count, { currentCount, previousCount in
            // TODO: This doesn't work for some reason.
            if currentCount < previousCount {
                isSearchFocused = true
            }
        })
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
            SearchFilter.keyValue("set", .equal, "7ED"),
            SearchFilter.keyValue("manavalue", .greaterThanOrEqual, "4"),
            SearchFilter.keyValue("power", .greaterThan, "3"),
        ]
        @State private var inputText = ""
        @FocusState private var isFocused: Bool

        var body: some View {
            VStack {
                Spacer()
                BottomBarFilterView(
                    filters: $filters,
                    inputText: $inputText,
                    isSearchFocused: _isFocused,
                    onFilterSetTap: { print("Filter set tapped") }
                )
            }
        }
    }

    return PreviewWrapper()
}
