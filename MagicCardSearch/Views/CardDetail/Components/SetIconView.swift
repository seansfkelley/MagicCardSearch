import SwiftUI
import SVGKit
import ScryfallKit
import OSLog
import Cache

private let logger = Logger(subsystem: "MagicCardSearch", category: "SetIconView")

private enum LoadError: Error, LocalizedError {
    case missingSetMetadata
    case failedToLoadSVG
    case failedToCreateSVGImage
    case failedToRenderUIImage

    var errorDescription: String? {
        switch self {
        case .failedToLoadSVG: "Failed to load SVG from the server"
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

        var description: String { "\(setCode.rawValue)@\(size)" }
    }

    private static let svgDataCache: any StorageAware<SetCode, Data> = bestEffortCache(
        memory: .init(expiry: .never, countLimit: 10),
        disk: .init(name: "SetIconSvg", expiry: .days(30)),
    )
    private static let renderedImageCache: any StorageAware<RenderedImageCacheKey, UIImage> = bestEffortCache(
        memory: .init(expiry: .never, countLimit: 10),
        disk: .init(name: "SetIconUIImage", expiry: .days(30)),
        transformer: uiImagePngTransformer(),
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
                Image(systemName: "questionmark.app.dashed")
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

            let svgImage = try await getSvgImageThroughCache()

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
            logger.error("failed to load SVG icon for key=\(renderedImageCacheKey) with error=\(error)")

            self.imageResult = .errored(nil, error)
        }
    }

    private func getSvgImageThroughCache() async throws -> SVGKImage {
        let set = scryfallCatalogs.sets?[setCode]
        guard let set, let url = URL(string: set.iconSvgUri) else {
            throw LoadError.missingSetMetadata
        }

        if let cachedData = (try? Self.svgDataCache.entry(forKey: setCode))?.object {
            logger.trace("hit cache for SVG data for icon with set=\(setCode.rawValue)")

            // This is a sentinel value. Don't remove it from the cache.
            if cachedData.isEmpty {
                throw LoadError.failedToLoadSVG
            }

            guard let img = SVGKImage(data: cachedData) else {
                // This is just bad data. Maybe we upgraded the SVG library and this cached data no
                // longer parses?
                try Self.svgDataCache.removeObject(forKey: setCode)

                // This is a little misleading because at this point we have already dumped the data
                // from the cache and could hit the load-from-network path, but this code path is
                // already so hilariously unlikely that I'll keep it simple and just make the UI
                // have to wait to retrigger a load by rendering the same icon again somewhere else.
                //
                // We also don't want to get into an infinite recursion in the even-less-likely case
                // that we failed to remove it from cache, so we won't simply just call ourselves.
                throw LoadError.failedToCreateSVGImage
            }

            return img
        } else {
            logger.info("requesting SVG data for icon for set=\(setCode.rawValue) from url=\(url)")
            let data: Data
            do {
                data = (try await URLSession.shared.data(from: url)).0
            } catch {
                logger.error("failed to load remote SVG for set=\(setCode.rawValue) with error=\(error)")

                // Temporarily cache a known-bad payload so we don't keep slamming the server
                // if it's failing and/or we have flaky internet. We check for this, above.
                //
                // Don't put this in a do-catch because if we fail to cache it, we don't have
                // anything we would rather do.
                //
                // This is extremely unlikely, so we'll just eat the cost of new network requests on
                // every render since the only way to avoid that would be to layer an infallible
                // cache on top of this one, which is just overengineered.
                try Self.svgDataCache.setObject(Data(), forKey: setCode, expiry: .hours(1))

                throw LoadError.failedToLoadSVG
            }

            // Don't cache the data until we know that it parses.
            guard let img = SVGKImage(data: data) else {
                // Same reasoning for storing bad data and no do-catch as above.
                try Self.svgDataCache.setObject(Data(), forKey: setCode, expiry: .hours(1))

                throw LoadError.failedToCreateSVGImage
            }

            // Same reasoning for the lack of do-catch here as above, except that the one thing we
            // might try would be to set the empty data in the cache, and that would presumably also
            // fail, so it doesn't really get us anything to try.
            try Self.svgDataCache.setObject(data, forKey: setCode, expiry: nil)

            return img
        }
    }
}
