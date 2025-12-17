//
//  SetIconView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-09.
//

import SwiftUI
import SVGKit
import ScryfallKit

struct SetIconView: View {
    struct RenderedImageCacheKey: Hashable, Sendable {
        let setCode: String
        let size: CGFloat
    }
    
    private static let svgDataCache: any Cache<String, Data> = {
        let memoryCache = MemoryCache<String, Data>(expiration: .interval(60 * 60 * 24))
        return if let diskCache = DiskCache<String, Data>(name: "SymbolSvg", expiration: .interval(60 * 60 * 24 * 30)) {
            HybridCache(memoryCache: memoryCache, diskCache: diskCache)
        } else {
            memoryCache
        }
    }()
    
    private static let renderedImageCache: any Cache<RenderedImageCacheKey, UIImage> = MemoryCache<RenderedImageCacheKey, UIImage>(
        expiration: .never
    )
    
    let setCode: String
    var size: CGFloat = 32
    
    @State private var renderedImage: UIImage?
    @State private var isLoading = true
    
    private var imageCacheKey: RenderedImageCacheKey {
        RenderedImageCacheKey(setCode: setCode.lowercased(), size: size)
    }
    
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
            await loadAndRender()
        }
    }
    
    private func loadAndRender() async {
        // Check rendered image cache
        if let renderedImage = Self.renderedImageCache[imageCacheKey] {
            await MainActor.run {
                self.renderedImage = renderedImage
                self.isLoading = false
            }
            return
        }
        
        let symbolResult = await ScryfallMetadataCache.shared.symbol(self.symbol)
        guard case .success(let symbolData) = symbolResult,
              let svgUriString = symbolData.svgUri,
              let url = URL(string: svgUriString) else {
            await MainActor.run { isLoading = false }
            return
        }
        
        let svgCacheKey = setCode.lowercased()
        
        do {
            // Try to get SVG data from cache, or fetch and cache it
            let svgData = try await Self.svgDataCache.get(forKey: svgCacheKey) {
                // Fetch SVG data from network
                print("Requesting icon \(url)")
                let (data, _) = try await URLSession.shared.data(from: url)
                return data
            }
            
            // Parse and render SVG
            guard let svgImage = SVGKImage(data: svgData) else {
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
            
            // Cache the rendered image (wrap in CodableImage)
            Self.renderedImageCache[imageCacheKey] = uiImage.codable
            
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
