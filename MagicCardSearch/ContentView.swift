//
//  ContentView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI

struct ContentView: View {
    @State private var searchText = ""
    @State private var showTopBar = true
    @State private var lastScrollOffset: CGFloat = 0
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main scrollable content
            ScrollView {
                LazyVStack(spacing: 20, pinnedViews: []) {
                    // Placeholder content
                    ForEach(0..<20) { index in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 120)
                            .overlay(
                                Text("Search Result \(index + 1)")
                                    .font(.headline)
                            )
                            .padding(.horizontal)
                    }
                    
                    // Bottom padding to account for search bar
                    Color.clear.frame(height: 100)
                }
                .padding(.top, 60) // Space for top bar
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                handleScroll(offset: value)
            }
            
            // Top bar with hide/show animation
            if showTopBar {
                TopBarView()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom) {
            SearchBarView(unparsedInputText: $searchText)
        }
        .animation(.easeInOut(duration: 0.25), value: showTopBar)
    }
    
    private func handleScroll(offset: CGFloat) {
        // Negative offset means scrolling down, positive means scrolling up
        withAnimation(.easeInOut(duration: 0.25)) {
            if offset < -80 {
                // Scrolled down enough to hide the bar
                showTopBar = false
            } else if offset > -50 {
                // Near the top or scrolling up, show the bar
                showTopBar = true
            }
        }
        
        lastScrollOffset = offset
    }
}

// MARK: - Top Bar

struct TopBarView: View {
    var body: some View {
        HStack {
            // Left icon button
            Button(action: {
                // Action for left button
                print("Left button tapped")
            }) {
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            // Center logo
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.title)
                .foregroundStyle(.tint)
            
            Spacer()
            
            // Right icon button
            Button(action: {
                // Action for right button
                print("Right button tapped")
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Preference Key for Scroll Offset

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
