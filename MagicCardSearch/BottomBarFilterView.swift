//
//  BottomBarFilterView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-06.
//

import SwiftUI

struct BottomBarFilterView: View {
    @Binding var filters: [SearchFilter]
    @Binding var inputText: String
    @Binding var inputSelection: TextSelection?
    @Binding var pendingSelection: TextSelection?
    @FocusState var isSearchFocused: Bool
    let historyProvider: AutocompleteProvider
    let onFilterEdit: (SearchFilter) -> Void
    
    // Calculate max height based on pill dimensions without hardcoding
    // Each pill is 32pt tall with 8pt spacing = 40pt per line
    // 3.5 lines = 3.5 * 40 = 140pt
    private var maxPillsHeight: CGFloat {
        let pillHeight: CGFloat = 32
        let lineSpacing: CGFloat = 8
        let lines: CGFloat = 4
        return (pillHeight + lineSpacing) * lines
    }

    var body: some View {
        VStack(spacing: 0) {
            if !filters.isEmpty {
                ScrollView {
                    GlassEffectContainer(spacing: 8) {
                        ReflowingFilterPillsView(
                            filters: $filters,
                            onFilterEdit: onFilterEdit
                        )
                    }
                    .padding()
                }
                .frame(maxHeight: maxPillsHeight)
                .fixedSize(horizontal: false, vertical: true)
                .mask {
                    VStack(spacing: 0) {
                        Rectangle()
                        LinearGradient(
                            colors: [.black, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 20)
                    }
                }
                
                Divider()
                    .padding(.horizontal)
            }
            
            SearchBarView(
                filters: $filters,
                inputText: $inputText,
                inputSelection: $inputSelection,
                historyProvider: historyProvider,
                isSearchFocused: _isSearchFocused
            )
            .padding(.vertical)
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        .padding()
        .onChange(of: isSearchFocused) { _, _ in
            if let s = pendingSelection {
                inputSelection = s
                pendingSelection = nil
            }
        }
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
        @State private var inputSelection: TextSelection?
        @State private var pendingSelection: TextSelection?
        @State private var historyProvider = AutocompleteProvider()
        @FocusState private var isFocused: Bool

        var body: some View {
            VStack {
                Spacer()
                BottomBarFilterView(
                    filters: $filters,
                    inputText: $inputText,
                    inputSelection: $inputSelection,
                    pendingSelection: $pendingSelection,
                    isSearchFocused: _isFocused,
                    historyProvider: historyProvider,
                    onFilterEdit: { filter in
                        print("Editing filter: \(filter)")
                    }
                )
            }
        }
    }

    return PreviewWrapper()
}
