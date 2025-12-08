//
//  SyntaxReferenceView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI
import WebKit

struct SyntaxReferenceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchVisible = false
    
    var body: some View {
        NavigationStack {
            WebView(url: URL(string: "https://scryfall.com/docs/syntax"))
                .findNavigator(isPresented: $searchVisible)
                .navigationTitle("Syntax Reference")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            searchVisible.toggle()
                        } label: {
                            Label("Find in Page", systemImage: "magnifyingglass")
                        }
                    }
                }
        }
    }
}

#Preview {
    SyntaxReferenceView()
}
