//
//  SetIconView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-09.
//

import SwiftUI
import SVGKit

struct SetIconView: View {
    private static let setIconCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        return cache
    }()
    
    let setCode: String
    var size: CGFloat = 32
    
    @State private var renderedImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = renderedImage {
                Image(uiImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else if isLoading {
                ProgressView()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "square.stack.3d.up")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            await loadAndRenderSVG()
        }
    }
    
    // swiftlint:disable:next function_body_length
    private func loadAndRenderSVG() async {
        let cacheKey = "\(setCode.lowercased())_\(Int(size))" as NSString
        
        // Check cache first
        if let cachedImage = SetIconView.setIconCache.object(forKey: cacheKey) {
            _ = await NetworkRequestSpan.begin("svg: \(setCode)", category: "svg", fromCache: true)
            await MainActor.run {
                self.renderedImage = cachedImage
                self.isLoading = false
            }
            return
        }
        
        let urlString = "https://svgs.scryfall.io/sets/\(setCode.lowercased()).svg"
        
        guard let url = URL(string: urlString) else {
            await MainActor.run { isLoading = false }
            return
        }
        
        do {
            let data = try await withNetworkLogging("svg: \(setCode)", category: "svg") {
                let (data, _) = try await URLSession.shared.data(from: url)
                return data
            } metadata: { data in
                ["bytes": data.count]
            }
            
            // Parse and render SVG
            guard let svgImage = SVGKImage(data: data) else {
                await MainActor.run { isLoading = false }
                return
            }
            
            // Get the original SVG size to preserve aspect ratio
            let originalSize = svgImage.size
            
            // Scale to fit within target size while maintaining aspect ratio
            let aspectRatio = originalSize.width / originalSize.height
            let scaledSize = CGSize(
                width: size * aspectRatio,
                height: size
            )
            
            // Set the scaled size
            svgImage.size = scaledSize
            
            // Convert to UIImage
            guard let uiImage = svgImage.uiImage else {
                await MainActor.run { isLoading = false }
                return
            }
            
            // Cache the rendered image
            SetIconView.setIconCache.setObject(uiImage, forKey: cacheKey)
            
            await MainActor.run {
                self.renderedImage = uiImage
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
