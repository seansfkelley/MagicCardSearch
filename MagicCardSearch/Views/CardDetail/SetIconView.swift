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
    private struct RenderedImageCacheKey: Hashable {
        let setCode: SetCode
        let size: CGFloat
    }
    
    private static let svgDataCache: any Cache<SetCode, Data> = {
        let memoryCache = MemoryCache<SetCode, Data>(expiration: .interval(60 * 60 * 24))
        return if let diskCache = DiskCache<SetCode, Data>(name: "SetIconSvg", expiration: .interval(60 * 60 * 24 * 30)) {
            HybridCache(memoryCache: memoryCache, diskCache: diskCache)
        } else {
            memoryCache
        }
    }()
    
    private static var renderedImageCache: any Cache<RenderedImageCacheKey, UIImage> = {
        return MemoryCache<RenderedImageCacheKey, UIImage>(expiration: .never)
    }()
    
    let setCode: SetCode
    var size: CGFloat = 32
    
    private var renderedImageCacheKey: RenderedImageCacheKey {
        RenderedImageCacheKey(setCode: setCode, size: size)
    }
    
    @State private var imageResult: LoadableResult<UIImage, Error> = .unloaded
    
    var body: some View {
        Group {
            if let image = imageResult.latestValue {
                Image(uiImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
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
        guard case .unloaded = imageResult else {
            return
        }
        
        if let renderedImage = Self.renderedImageCache[renderedImageCacheKey] {
            self.imageResult = .loaded(renderedImage, nil)
            return
        }
        
        let set = ScryfallCatalogs.sync?.sets[setCode]
        guard let set, let url = URL(string: set.iconSvgUri) else {
            imageResult = .errored(nil, NSError(domain: "SetIconView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get set metadata"]))
            return
        }
        
        do {
            imageResult = .loading(nil, nil)
            
            let svgData = try await Self.svgDataCache.get(forKey: setCode) {
                print("Requesting icon \(url)")
                let (data, _) = try await URLSession.shared.data(from: url)
                return data
            }
            
            guard let svgImage = SVGKImage(data: svgData) else {
                imageResult = .errored(nil, NSError(domain: "SetIconView", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create SVG image"]))
                return
            }
            
            let originalSize = svgImage.size
            
            let scale = size / max(originalSize.width, originalSize.height)
            let scaledSize = CGSize(
                width: originalSize.width * scale,
                height: originalSize.height * scale
            )
            
            // n.b. we scale in SVG space, not in UIImage space, to get a smoother result. This means
            // we clog the memory cache with duplicates for every size, but we use pretty consistent
            // sizes so it should be fine.
            svgImage.size = scaledSize
            
            guard let uiImage = svgImage.uiImage else {
                imageResult = .errored(nil, NSError(domain: "SetIconView", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to render SVG to UIImage"]))
                return
            }
            
            Self.renderedImageCache[renderedImageCacheKey] = uiImage
            
            self.imageResult = .loaded(uiImage, nil)
        } catch {
            self.imageResult = .errored(nil, error)
        }
    }
}
