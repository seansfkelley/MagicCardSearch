import SwiftUI
import SVGKit
import ScryfallKit
import OSLog
import Cache

private let logger = Logger(subsystem: "MagicCardSearch", category: "SetIconView")

private enum LoadError: Error, LocalizedError {
    case missingSetMetadata
    case failedToCreateSVGImage
    case failedToRenderUIImage

    var errorDescription: String? {
        switch self {
        case .missingSetMetadata: "Failed to get set metadata"
        case .failedToCreateSVGImage: "Failed to create SVG image"
        case .failedToRenderUIImage: "Failed to render SVG to UIImage"
        }
    }
}

struct SetIconView: View {
    @Environment(ScryfallCatalogs.self) private var scryfallCatalogs

    private struct RenderedImageCacheKey: Hashable, CustomStringConvertible {
        let setCode: SetCode
        let size: CGFloat

        var description: String { "\(setCode.normalized)@\(size)" }
    }

    private static let svgDataCache: any StorageAware<SetCode, Data> = bestEffortCache(
        memory: .init(expiry: .never, countLimit: 10),
        disk: .init(name: "SetIconSvg", expiry: .seconds(60 * 60 * 24 * 30)),
    )
    private static let renderedImageCache: any StorageAware<RenderedImageCacheKey, UIImage> = bestEffortCache(
        memory: .init(expiry: .never, countLimit: 10),
        disk: .init(name: "SetIconUIImage", expiry: .seconds(60.0 * 60 * 24 * 30)),
        transformer: .init(toData: { img in img.pngData()! }, fromData: { data in UIImage(data: data)! }),
    )

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
        .onFirstAppear {
            Task {
                await loadAndRender()
            }
        }
    }
    
    private func loadAndRender() async {
        guard case .unloaded = imageResult else {
            return
        }
        
        if let renderedImage = try? Self.renderedImageCache.entry(forKey: renderedImageCacheKey) {
            logger.trace("hit cache for rendered SVG icon for key=\(renderedImageCacheKey)")
            self.imageResult = .loaded(renderedImage.object, nil)
            return
        }

        do {
            imageResult = .loading(nil, nil)
            
            let set = scryfallCatalogs.sets?[setCode]
            guard let set, let url = URL(string: set.iconSvgUri) else {
                throw LoadError.missingSetMetadata
            }

            var svgData = (try? Self.svgDataCache.entry(forKey: setCode))?.object
            if svgData != nil {
                logger.trace("hit cache for SVG data for icon with key=\(renderedImageCacheKey)")
            } else {
                logger.info("requesting SVG data for icon for set=\(setCode.normalized) from url=\(url)")
                let (data, _) = try await URLSession.shared.data(from: url)
                svgData = data
                try Self.svgDataCache.setObject(data, forKey: setCode, expiry: nil)
            }
            
            guard let svgImage = SVGKImage(data: svgData) else {
                throw LoadError.failedToCreateSVGImage
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
                throw LoadError.failedToRenderUIImage
            }

            do {
                try Self.renderedImageCache.setObject(uiImage, forKey: renderedImageCacheKey, expiry: nil)
                logger.trace("set cache for rendered SVG icon for key=\(renderedImageCacheKey)")
            } catch {
                logger.warning("failed to set cache for rendered SVG icon for key=\(renderedImageCacheKey) with error=\(error)")
            }

            self.imageResult = .loaded(uiImage, nil)
        } catch {
            self.imageResult = .errored(nil, error)
        }
    }
}
