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
    
    @State private var imageResult: LoadableResult<UIImage> = .unloaded
    
    var body: some View {
        Group {
            if case .success(let image) = imageResult.latestResult {
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
    
    // swiftlint:disable:next function_body_length
    private func loadAndRender() async {
        switch imageResult {
        case .loaded, .loading:
            return
        case .unloaded:
            break
        }
        
        await MainActor.run {
            imageResult = .loading(nil)
        }
        
        if let renderedImage = Self.renderedImageCache[renderedImageCacheKey] {
            await MainActor.run {
                self.imageResult = .loaded(.success(renderedImage))
            }
            return
        }
        
        let set = ScryfallMetadataCache.shared.sets[setCode]
        guard let set, let url = URL(string: set.iconSvgUri) else {
            await MainActor.run {
                imageResult = .loaded(.failure(NSError(domain: "SetIconView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get set metadata"])))
            }
            return
        }
        
        do {
            let svgData = try await Self.svgDataCache.get(forKey: setCode) {
                print("Requesting icon \(url)")
                let (data, _) = try await URLSession.shared.data(from: url)
                return data
            }
            
            guard let svgImage = SVGKImage(data: svgData) else {
                await MainActor.run {
                    imageResult = .loaded(.failure(NSError(domain: "SetIconView", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create SVG image"])))
                }
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
                await MainActor.run {
                    imageResult = .loaded(.failure(NSError(domain: "SetIconView", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to render SVG to UIImage"])))
                }
                return
            }
            
            Self.renderedImageCache[renderedImageCacheKey] = uiImage
            
            await MainActor.run {
                self.imageResult = .loaded(.success(uiImage))
            }
        } catch {
            await MainActor.run {
                self.imageResult = .loaded(.failure(error))
            }
        }
    }
}
