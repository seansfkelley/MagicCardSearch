//
//  LoggedAsyncImage.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-14.
//

import SwiftUI
import OSLog

/// A wrapper around AsyncImage that logs all network activity
/// Use this instead of AsyncImage directly to get automatic network logging
struct LoggedAsyncImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (AsyncImagePhase) -> Content
    
    @State private var span: NetworkRequestSpan?
    
    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
    }
    
    var body: some View {
        AsyncImage(url: url) { phase in
            content(phase)
                .task {
                    await handlePhaseChange(phase)
                }
        }
    }
    
    private func handlePhaseChange(_ phase: AsyncImagePhase) async {
        guard let url = url else { return }
        
        switch phase {
        case .empty:
            // Start logging when image begins loading
            span = await NetworkRequestSpan.begin("image: \(url.absoluteString)", category: "images", fromCache: false)
            
        case .success:
            await span?.end()
            span = nil
            
        case .failure(let error):
            await span?.fail(error: error)
            span = nil
            
        @unknown default:
            break
        }
    }
}

// MARK: - Convenience Initializers

extension LoggedAsyncImage {
    /// Simplified initializer that matches the most common AsyncImage usage
    init(url: URL?) where Content == AnyView {
        self.url = url
        self.content = { phase in
            AnyView(
                Group {
                    if let image = phase.image {
                        image
                    } else if phase.error != nil {
                        Image(systemName: "exclamationmark.triangle")
                    } else {
                        ProgressView()
                    }
                }
            )
        }
    }
}
