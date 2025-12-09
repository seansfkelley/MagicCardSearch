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
    @Binding var isExpanded: Bool
    let warnings: [String]
    @Binding var showWarningsPopover: Bool
    let onFilterEdit: (SearchFilter) -> Void
    
    @Namespace private var animation
    
    private let collapsedButtonSize: CGFloat = 44
    
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
            if isExpanded {
                if !filters.isEmpty {
                    HStack(alignment: .bottom) {
                        if !warnings.isEmpty {
                            WarningsPillView(
                                warnings: warnings,
                                isExpanded: $showWarningsPopover
                            )
                            .matchedGeometryEffect(id: "warnings", in: animation)
                        }
                        
                        Spacer()
                        
                        Button(role: .destructive, action: onClearAll) {
                            Text("Clear all")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                        }
                        .glassEffect(.regular.interactive())
                        .matchedGeometryEffect(id: "clearAll", in: animation)
                    }
                    .padding(.bottom, 8)
                }
                
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
                        isSearchFocused: _isSearchFocused
                    )
                    .matchedGeometryEffect(id: "searchBar", in: animation)
                }
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
                .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            isSearchFocused = true
                        }
                )
            } else {
                HStack(spacing: 12) {
                    if !warnings.isEmpty {
                        Button(action: {
                            onExpandTap()
                            showWarningsPopover = true
                        }) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.system(size: 20))
                                .frame(width: collapsedButtonSize, height: collapsedButtonSize)
                        }
                        .glassEffect(.regular.interactive(), in: .circle)
                        .matchedGeometryEffect(id: "warnings", in: animation)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(filters.enumerated()), id: \.offset) { index, filter in
                                FilterPillView(
                                    filter: filter,
                                    onTap: {
                                        onExpandTap()
                                        isSearchFocused = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(height: collapsedButtonSize)
                    .clipShape(.capsule)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .matchedGeometryEffect(id: "searchBar", in: animation)
                    .onTapGesture {
                        onExpandTap()
                        isSearchFocused = true
                    }
                    
                    if !filters.isEmpty {
                        Button(action: onClearAll) {
                            Image(systemName: "xmark")
                                .foregroundStyle(.red)
                                .font(.system(size: 20))
                                .frame(width: collapsedButtonSize, height: collapsedButtonSize)
                        }
                        .glassEffect(.regular.interactive(), in: .circle)
                        .matchedGeometryEffect(id: "clearAll", in: animation)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
        .padding()
        .onChange(of: isSearchFocused) { _, _ in
            if let s = pendingSelection {
                inputSelection = s
                pendingSelection = nil
            }
        }
    }
    
    private func onClearAll() {
        filters.removeAll()
        inputText = ""
        inputSelection = nil
        isExpanded = true
        isSearchFocused = true
    }
    
    private func onExpandTap() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded = true
        }
    }
}

// MARK: - Warnings Pill View

private struct WarningsPillView: View {
    let warnings: [String]
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isExpanded {
                ForEach(Array(warnings.enumerated()), id: \.offset) { index, warning in
                    Text(warning)
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if index < warnings.count - 1 {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            } else {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = true
                    }
                } label: {
                    Text(warnings.count == 1 ? "1 warning" : "\(warnings.count) warnings")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                }
            }
        }
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            if isExpanded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded = false
                }
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
        @State private var isCollapsed = false
        @State private var showWarningsPopover = false
        @FocusState private var isFocused: Bool

        var body: some View {
            VStack {
                Spacer()
                
                // Toggle for testing
                Button("Toggle Collapsed") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isCollapsed.toggle()
                    }
                }
                .padding()
                
                BottomBarFilterView(
                    filters: $filters,
                    inputText: $inputText,
                    inputSelection: $inputSelection,
                    pendingSelection: $pendingSelection,
                    isSearchFocused: _isFocused,
                    isExpanded: $isCollapsed,
                    warnings: ["Warning 1", "Warning 2"],
                    showWarningsPopover: $showWarningsPopover,
                    onFilterEdit: { filter in
                        print("Editing filter: \(filter)")
                    },
                )
            }
            .background(Color(uiColor: .systemBackground))
        }
    }

    return PreviewWrapper()
}
