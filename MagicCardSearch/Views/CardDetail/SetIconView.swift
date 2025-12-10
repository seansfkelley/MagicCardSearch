//
//  SetIconView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-09.
//

import SwiftUI
import SVGKit

// Global cache for rendered set icons - NSCache is thread-safe and handles memory automatically
private let setIconCache: NSCache<NSString, UIImage> = {
    let cache = NSCache<NSString, UIImage>()
    cache.countLimit = 100
    return cache
}()

struct SetIconView: View {
    let setCode: String
    @State private var renderedImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = renderedImage {
                Image(uiImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
            } else if isLoading {
                ProgressView()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "square.stack.3d.up")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            await loadAndRenderSVG()
        }
    }
    
    private func loadAndRenderSVG() async {
        let cacheKey = setCode.lowercased() as NSString
        
        // Check cache first
        if let cachedImage = setIconCache.object(forKey: cacheKey) {
            await MainActor.run {
                self.renderedImage = cachedImage
                self.isLoading = false
            }
            return
        }
        
        let urlString = "https://svgs.scryfall.io/sets/\(setCode.lowercased()).svg"
        
        guard let url = URL(string: urlString) else {
            print("SetIconView: Invalid URL for set code: \(setCode)")
            await MainActor.run { isLoading = false }
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Parse and render SVG
            guard let svgImage = SVGKImage(data: data) else {
                print("SetIconView: Failed to parse SVG for set: \(setCode)")
                await MainActor.run { isLoading = false }
                return
            }
            
            // Get the original SVG size to preserve aspect ratio
            let originalSize = svgImage.size
            
            // Scale to fit within 32pt while maintaining aspect ratio
            let targetHeight: CGFloat = 32
            let aspectRatio = originalSize.width / originalSize.height
            let scaledSize = CGSize(
                width: targetHeight * aspectRatio,
                height: targetHeight
            )
            
            // Set the scaled size
            svgImage.size = scaledSize
            
            // Convert to UIImage
            guard let uiImage = svgImage.uiImage else {
                print("SetIconView: Failed to convert SVG to UIImage for set: \(setCode)")
                await MainActor.run { isLoading = false }
                return
            }
            
            // Cache the rendered image
            setIconCache.setObject(uiImage, forKey: cacheKey)
            
            await MainActor.run {
                self.renderedImage = uiImage
                self.isLoading = false
            }
            
        } catch {
            print("SetIconView: Error loading SVG for set \(setCode): \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
