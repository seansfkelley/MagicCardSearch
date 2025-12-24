//
//  BottomBarFilterView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-06.
//

import SwiftUI

struct FakeSearchBarButtonView: View {
    var filters: [SearchFilter]
    let warnings: [String]
    @Binding var isSearchBarVisible: Bool
    var onClearAll: () -> Void

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
                if showWarningsPopover {
                    WarningsPillView(
                        warnings: warnings,
                        mode: .pill,
                        isExpanded: $showWarningsPopover
                    )
                    .matchedGeometryEffect(id: "warnings", in: animation)
                }
            }
            .padding(.bottom, showWarningsPopover ? 8 : 0)
            
            HStack {
                if !showWarningsPopover {
                    WarningsPillView(
                        warnings: warnings,
                        mode: .icon(collapsedButtonSize),
                        isExpanded: $showWarningsPopover
                    )
                    .matchedGeometryEffect(id: "warnings", in: animation)
                }
                
                ZStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 16)
                            .padding(.vertical, 12)
                            .padding(.leading, 12)
                            .padding(.trailing, 4)
                            .opacity(searchIconOpacity)
                        if filters.isEmpty {
                            Text("Search for cards...")
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .frame(width: 16, height: 16)
                                .padding(.leading, 4)
                                .padding(.trailing, 4)
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
                .contentShape(Rectangle())
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
                .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            isSearchBarVisible = true
                        }
                )
                
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
        .padding(.horizontal)
        .padding(.bottom)
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
