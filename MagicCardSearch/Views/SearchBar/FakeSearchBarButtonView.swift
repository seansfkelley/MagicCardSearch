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
    var onClearAll: () -> Void
    var onTap: () -> Void

    @State var showWarningsPopover: Bool = false
    @State var searchIconOpacity: CGFloat = 1
    @Namespace private var animation
    
    private let buttonSize: CGFloat = 44
    private let searchIconFadeExtent: CGFloat = 24

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
                        mode: .icon(buttonSize),
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
                    .frame(height: buttonSize)
                }
                .contentShape(Rectangle())
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
                .simultaneousGesture(TapGesture().onEnded { onTap() })
                
                // No idea why this is here when there is no equivalent for the warnings view,
                // which doesn't seem to need it to keep itself spaced out from the pills view.
                Spacer()

                if !filters.isEmpty {
                    Button(role: .destructive, action: onClearAll) {
                        Image(systemName: "xmark")
                            .foregroundStyle(.red)
                            .font(.system(size: 20))
                            .frame(width: buttonSize, height: buttonSize)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
}
