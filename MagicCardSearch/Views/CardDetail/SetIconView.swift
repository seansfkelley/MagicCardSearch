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
        let setCode: SetCode
        let size: CGFloat
    }
    
    private static let svgDataCache: any Cache<SetCode, Data> = {
        let memoryCache = MemoryCache<SetCode, Data>(expiration: .interval(60 * 60 * 24))
        return if let diskCache = DiskCache<SetCode, Data>(name: "SymbolSvg", expiration: .interval(60 * 60 * 24 * 30)) {
            HybridCache(memoryCache: memoryCache, diskCache: diskCache)
        } else {
            memoryCache
        }
    }()
    
    private static var renderedImageCache: any Cache<RenderedImageCacheKey, UIImage> = MemoryCache<RenderedImageCacheKey, UIImage>(
        expiration: .never
    )
    
    let setCode: SetCode
    var size: CGFloat = 32
    
    @State private var renderedImage: UIImage?
    @State private var isLoading = true
    
    private var imageCacheKey: RenderedImageCacheKey {
        RenderedImageCacheKey(setCode: setCode, size: size)
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
        if let renderedImage = Self.renderedImageCache[imageCacheKey] {
            await MainActor.run {
                self.renderedImage = renderedImage
                self.isLoading = false
            }
            return
        }
        
        let symbolResult = await ScryfallMetadataCache.shared.set(self.setCode)
        guard case .success(let symbolData) = symbolResult,
              let url = URL(string: symbolData.iconSvgUri) else {
            await MainActor.run { isLoading = false }
            return
        }
        
        do {
            let svgData = try await Self.svgDataCache.get(forKey: setCode) {
                print("Requesting icon \(url)")
                let (data, _) = try await URLSession.shared.data(from: url)
                return data
            }
            
            guard let svgImage = SVGKImage(data: svgData) else {
                await MainActor.run { isLoading = false }
                return
            }
            
            let originalSize = svgImage.size
            
            let aspectRatio = originalSize.width / originalSize.height
            let scaledSize = CGSize(
                width: size * aspectRatio,
                height: size
            )
            
            svgImage.size = scaledSize
            
            guard let uiImage = svgImage.uiImage else {
                await MainActor.run { isLoading = false }
                return
            }
            
            Self.renderedImageCache[imageCacheKey] = uiImage
            
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
