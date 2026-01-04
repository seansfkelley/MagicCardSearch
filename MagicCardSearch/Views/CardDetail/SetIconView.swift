import SwiftUI
import SVGKit
import ScryfallKit
import Logging

private let logger = Logger(label: "SetIconView")

struct SetIconView: View {
    @Environment(ScryfallCatalogs.self) private var scryfallCatalogs

    private struct RenderedImageCacheKey: Hashable {
        let setCode: SetCode
        let size: CGFloat
    }

    // TODO: Make this a SQLite-backed disk cache too, I guess.
    private static let svgDataCache = MemoryCache<SetCode, Data>()
    private static var renderedImageCache = MemoryCache<RenderedImageCacheKey, UIImage>()

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

        let set = scryfallCatalogs.sets?[setCode]
        guard let set, let url = URL(string: set.iconSvgUri) else {
            imageResult = .errored(nil, NSError(domain: "SetIconView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get set metadata"]))
            return
        }
        
        do {
            imageResult = .loading(nil, nil)

            let svgData = try await Self.svgDataCache.get(setCode) {
                logger.info("requesting set icon", metadata: [
                    "setCode": "\(setCode.normalized)",
                    "url": "\(url)",
                ])
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
