//
//  ContentView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI

struct ContentView: View {
    @State private var filters: [SearchFilter] = []
    @State private var showTopBar = true
    
    var body: some View {
        ZStack(alignment: .top) {
            CardResultsView(filters: $filters)
            
            if showTopBar {
                TopBarView()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom) {
            SearchBarView(filters: $filters)
        }
        .animation(.easeInOut(duration: 0.25), value: showTopBar)
    }
}

// MARK: - Top Bar

struct TopBarView: View {
    var body: some View {
        HStack {
            Button(action: {
                print("Left button tapped")
            }) {
                Image(systemName: "line.3.horizontal")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.title)
                .foregroundStyle(.tint)
            
            Spacer()
            
            Button(action: {
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
