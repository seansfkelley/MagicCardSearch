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
    let warnings: [String]
    @Binding var showWarningsPopover: Bool
    let onFilterEdit: (SearchFilter) -> Void
    @State var searchIconOpacity: CGFloat = 1
    
    @Namespace private var animation
    
    private let collapsedButtonSize: CGFloat = 44
    private let searchIconFadeExtent: CGFloat = 24
    
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
            HStack(alignment: .bottom) {
                if isSearchFocused || showWarningsPopover {
                    WarningsPillView(
                        warnings: warnings,
                        mode: .pill,
                        isExpanded: $showWarningsPopover
                    )
                    .matchedGeometryEffect(id: "warnings", in: animation)
                }
                
                if isSearchFocused {
                    Spacer()
                    
                    ClearAllButton(
                        filters: filters,
                        mode: .pill,
                        onClearAll: onClearAll,
                    )
                    .matchedGeometryEffect(id: "clearAll", in: animation)
                }
            }
            .padding(.bottom, isSearchFocused || showWarningsPopover ? 8 : 0)
            
            HStack {
                if !isSearchFocused && !showWarningsPopover {
                    WarningsPillView(
                        warnings: warnings,
                        mode: .icon(collapsedButtonSize),
                        isExpanded: $showWarningsPopover
                    )
                    .matchedGeometryEffect(id: "warnings", in: animation)
                }
                
                VStack(spacing: 0) {
                    if isSearchFocused && !filters.isEmpty {
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
                    // In order to use isSearchFocused as the one and only state management for
                    // expanded/collapsed state, we need to (1) make sure that the TextField in this
                    // component is always rendered so that it _can_ take focus, and (2) that we
                    // don't conditionally create slightly different views depending on focus state.
                    // An earlier implementation of this used the `if` modifier for the latter,
                    // which triggered an infinite loop of observable changes. The workaround is
                    // here: ternaries, with `frame` and `clipped` being called unconditionally.
                    .frame(
                        width: isSearchFocused || filters.isEmpty ? nil : 0,
                        height: isSearchFocused || filters.isEmpty ? nil : 0
                    )
                    .clipped()
                    
                    if !isSearchFocused && !filters.isEmpty {
                        ZStack {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                    .padding(12)
                                    .opacity(searchIconOpacity)
                                Spacer()
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .padding(.trailing, 12)
                                        .hidden()
                                    
                                    ForEach(Array(filters.enumerated()), id: \.offset) { _, filter in
                                        FilterPillView(filter: filter)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                            .onScrollGeometryChange(
                                for: CGFloat.self,
                                of: { geometry in
                                    let x = geometry.contentOffset.x
                                    return x > searchIconFadeExtent ? searchIconFadeExtent : x < 0 ? 0 : x
                                },
                                action: { _, currentValue in
                                    searchIconOpacity = (searchIconFadeExtent - currentValue) / searchIconFadeExtent
                                })
                            .clipShape(.capsule)
                            .frame(maxWidth: .infinity)
                            .frame(height: collapsedButtonSize)
                        }
                    }
                }
                .contentShape(Rectangle())
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
                .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            isSearchFocused = true
                        }
                )
                
                if !isSearchFocused {
                    // No idea why this is here when there is no equivalent for the warnings view,
                    // which doesn't seem to need it to keep itself spaced out from the pills view.
                    Spacer()
                    
                    ClearAllButton(
                        filters: filters,
                        mode: .icon(collapsedButtonSize),
                        onClearAll: onClearAll,
                    )
                    .matchedGeometryEffect(id: "clearAll", in: animation)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
        .onChange(of: isSearchFocused) { _, _ in
            if let selection = pendingSelection {
                inputSelection = selection
                pendingSelection = nil
            }
        }
    }
    
    private func onClearAll() {
        filters.removeAll()
        inputText = ""
        inputSelection = nil
        isSearchFocused = true
    }
}

private enum HelperButtonMode {
    case pill, icon(CGFloat)
}

// MARK: - Warnings Pill View

private struct WarningsPillView: View {
    let warnings: [String]
    let mode: HelperButtonMode
    @Binding var isExpanded: Bool
    
    var body: some View {
        if warnings.isEmpty {
            EmptyView()
        } else if isExpanded {
            VStack(alignment: .leading, spacing: 0) {
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
            }
            .onTapGesture {
                if isExpanded {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                }
            }
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            Button(action: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    isExpanded = true
                }
            }) {
                switch mode {
                case .icon(let size):
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 20))
                        .frame(width: size, height: size)
                        .glassEffect(.regular.interactive(), in: .circle)
                case .pill:
                    Text(warnings.count == 1 ? "1 warning" : "\(warnings.count) warnings")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
            }
        }
    }
}

private struct ClearAllButton: View {
    let filters: [SearchFilter]
    let mode: HelperButtonMode
    let onClearAll: () -> Void
    
    var body: some View {
        if filters.isEmpty {
            EmptyView()
        } else {
            Button(role: .destructive, action: onClearAll) {
                switch mode {
                case .icon(let size):
                    Image(systemName: "xmark")
                        .foregroundStyle(.red)
                        .font(.system(size: 20))
                        .frame(width: size, height: size)
                        .glassEffect(.regular.interactive(), in: .circle)
                case .pill:
                    Text("Clear all")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var filters: [SearchFilter] = [
            .basic(.keyValue("set", .equal, "7ED")),
            .basic(.keyValue("manavalue", .greaterThanOrEqual, "4")),
            .basic(.keyValue("power", .greaterThan, "3")),
        ]
        @State private var inputText = ""
        @State private var inputSelection: TextSelection?
        @State private var pendingSelection: TextSelection?
        @State private var historyProvider = AutocompleteProvider()
        @State private var showWarningsPopover = false
        @FocusState private var isFocused: Bool

        var body: some View {
            VStack {
                Spacer()
                
                Button("Toggle Focus") {
                    isFocused.toggle()
                }
                .padding()
                
                BottomBarFilterView(
                    filters: $filters,
                    inputText: $inputText,
                    inputSelection: $inputSelection,
                    pendingSelection: $pendingSelection,
                    isSearchFocused: _isFocused,
                    warnings: ["Warning 1", "Warning 2"],
                    showWarningsPopover: $showWarningsPopover
                ) { filter in
                        print("Editing filter: \(filter)")
                }
            }
            .background(Color(uiColor: .systemBackground))
        }
    }

    return PreviewWrapper()
}
