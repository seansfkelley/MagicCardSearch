//
//  BottomBarFilterView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-06.
//

import SwiftUI

struct BottomBarFilterViewWithSearch: View {
    @Binding var filters: [SearchFilter]
    @Binding var inputText: String
    @Binding var inputSelection: TextSelection?
    @Binding var pendingSelection: TextSelection?
    let warnings: [String]
    let onFilterEdit: (SearchFilter) -> Void
    let searchHistoryTracker: SearchHistoryTracker
    let onSubmit: () -> Void
    @Bindable var autocompleteProvider: CombinedSuggestionProvider
    @Binding var isSearchBarVisible: Bool
    @FocusState var isSearchFocused: Bool

    @State var showWarningsPopover: Bool = false
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
                WarningsPillView(
                    warnings: warnings,
                    mode: .pill,
                    isExpanded: $showWarningsPopover
                )
                .matchedGeometryEffect(id: "warnings", in: animation)

                Spacer()

                ClearAllButton(
                    filters: filters,
                    mode: .pill,
                    onClearAll: onClearAll,
                )
                .matchedGeometryEffect(id: "clearAll", in: animation)
            }
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                if !filters.isEmpty {
                    ScrollView {
                        GlassEffectContainer(spacing: 8) {
                            ReflowingFilterPillsView(
                                filters: $filters,
                                onFilterEdit: onFilterEdit
                            )
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
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
                    isSearchBarVisible: $isSearchBarVisible,
                    autocompleteProvider: autocompleteProvider,
                    searchHistoryTracker: searchHistoryTracker,
                    onSubmit: onSubmit
                )
            }
            .contentShape(Rectangle())
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
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
