//
//  ManaSymbolView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI
import ScryfallKit
import SVGKit
import Cache

struct SymbolView: View {
    private static let svgDataCache: Storage<String, Data>? = {
        let diskConfig = DiskConfig(
            name: "SymbolSvg",
            expiry: .seconds(60 * 60 * 24 * 30),
            maxSize: 10_000_000,
        )
        let memoryConfig = MemoryConfig(
            expiry: .seconds(60 * 60 * 24),
        )
        
        return try? Storage<String, Data>(
            diskConfig: diskConfig,
            memoryConfig: memoryConfig,
            fileManager: FileManager.default,
            transformer: TransformerFactory.forData(),
        )
    }()
    
    struct RenderedImageCacheKey: Hashable {
        let symbol: String
        let size: CGFloat
        let oversize: CGFloat
    }
    
    private static let renderedImageCache = MemoryStorage<RenderedImageCacheKey, UIImage>(
        config: MemoryConfig(expiry: .never)
    )
    
    let symbol: String
    let size: CGFloat
    let oversize: CGFloat
    
    @State private var renderedImage: UIImage?
    @State private var isLoading = true
    
    private var imageCacheKey: RenderedImageCacheKey {
        RenderedImageCacheKey(symbol: symbol, size: size, oversize: oversize)
    }
    
    init?(
        _ symbol: String,
        size: CGFloat = 16,
        oversize: CGFloat? = nil,
        showDropShadow: Bool = false
    ) {
        let normalized = symbol.trimmingCharacters(in: .whitespaces).uppercased()
        let withBraces = normalized.hasPrefix("{") && normalized.hasSuffix("}")
            ? normalized
            : "{\(normalized)}"
        
        self.symbol = withBraces
        self.size = size
        self.oversize = oversize ?? size
    }
    
    var body: some View {
        Group {
            if let image = renderedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else if isLoading {
                Circle()
                    .fill(.secondary.opacity(0.2))
                    .frame(width: size, height: size)
            } else {
                Text(symbol)
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
            }
        }
        .task {
            await loadAndRender()
        }
    }
    
    private func loadAndRender() async {
        if let cachedImage = try? Self.renderedImageCache.object(forKey: imageCacheKey) {
            await MainActor.run {
                self.renderedImage = cachedImage
                self.isLoading = false
            }
            return
        }
        
        guard let symbol = try? await SymbologyCatalog.shared.getSymbol(byNotation: symbol),
              let svgUriString = symbol.svgUri,
              let url = URL(string: svgUriString) else {
            await MainActor.run { isLoading = false }
            return
        }
        
        do {
            // Try to get SVG data from cache, or fetch and cache it
            let svgData: Data
            if let cachedData = try? SymbolView.svgDataCache?.object(forKey: self.symbol) {
                svgData = cachedData
            } else {
                // Fetch SVG data from network
                let (data, _) = try await URLSession.shared.data(from: url)
                svgData = data
                
                // Cache the SVG data for future use
                try? SymbolView.svgDataCache?.setObject(data, forKey: self.symbol)
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
            
            // Cache the rendered image
            try? SymbolView.renderedImageCache.setObject(uiImage, forKey: renderedCacheKey)
            
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

#Preview("All Mana Symbols") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Basic Mana")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView("{W}", size: 32)
                    SymbolView("{U}", size: 32)
                    SymbolView("{B}", size: 32)
                    SymbolView("{R}", size: 32)
                    SymbolView("{G}", size: 32)
                    SymbolView("{C}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Generic/Colorless")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView("{0}", size: 32)
                    SymbolView("{1}", size: 32)
                    SymbolView("{2}", size: 32)
                    SymbolView("{3}", size: 32)
                    SymbolView("{4}", size: 32)
                    SymbolView("{5}", size: 32)
                }
                HStack(spacing: 8) {
                    SymbolView("{6}", size: 32)
                    SymbolView("{7}", size: 32)
                    SymbolView("{8}", size: 32)
                    SymbolView("{9}", size: 32)
                    SymbolView("{10}", size: 32)
                    SymbolView("{11}", size: 32)
                }
                HStack(spacing: 8) {
                    SymbolView("{12}", size: 32)
                    SymbolView("{13}", size: 32)
                    SymbolView("{14}", size: 32)
                    SymbolView("{15}", size: 32)
                    SymbolView("{16}", size: 32)
                    SymbolView("{20}", size: 32)
                }
                HStack(spacing: 8) {
                    SymbolView("{X}", size: 32)
                    SymbolView("{Y}", size: 32)
                    SymbolView("{Z}", size: 32)
                    SymbolView("{∞}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Hybrid Mana")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView("{W/U}", size: 32)
                    SymbolView("{W/B}", size: 32)
                    SymbolView("{U/B}", size: 32)
                    SymbolView("{U/R}", size: 32)
                    SymbolView("{B/R}", size: 32)
                }
                HStack(spacing: 8) {
                    SymbolView("{B/G}", size: 32)
                    SymbolView("{R/W}", size: 32)
                    SymbolView("{R/G}", size: 32)
                    SymbolView("{G/W}", size: 32)
                    SymbolView("{G/U}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Phyrexian Mana")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView("{W/P}", size: 32)
                    SymbolView("{U/P}", size: 32)
                    SymbolView("{B/P}", size: 32)
                    SymbolView("{R/P}", size: 32)
                    SymbolView("{G/P}", size: 32)
                    SymbolView("{C/P}", size: 32)
                    SymbolView("{H}", size: 32) // Rage Extractor
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Hybrid Generic/Colored")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView("{2/W}", size: 32)
                    SymbolView("{2/U}", size: 32)
                    SymbolView("{2/B}", size: 32)
                    SymbolView("{2/R}", size: 32)
                    SymbolView("{2/G}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Hybrid Colorless/Colored")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView("{C/W}", size: 32)
                    SymbolView("{C/U}", size: 32)
                    SymbolView("{C/B}", size: 32)
                    SymbolView("{C/R}", size: 32)
                    SymbolView("{C/G}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Hybrid Phyrexian")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView("{W/U/P}", size: 32)
                    SymbolView("{W/B/P}", size: 32)
                    SymbolView("{U/B/P}", size: 32)
                    SymbolView("{U/R/P}", size: 32)
                    SymbolView("{B/R/P}", size: 32)
                }
                HStack(spacing: 8) {
                    SymbolView("{B/G/P}", size: 32)
                    SymbolView("{R/W/P}", size: 32)
                    SymbolView("{R/G/P}", size: 32)
                    SymbolView("{G/W/P}", size: 32)
                    SymbolView("{G/U/P}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Special Symbols")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView("{S}", size: 32)
                    SymbolView("{T}", size: 32)
                    SymbolView("{Q}", size: 32)
                    SymbolView("{A}", size: 32)
                    SymbolView("{E}", size: 32)
                    SymbolView("{CHAOS}", size: 32)
                    SymbolView("{P}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("With Drop Shadows")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView("{W}", size: 32, showDropShadow: true)
                    SymbolView("{0}", size: 32, showDropShadow: true)
                    SymbolView("{U/B}", size: 32, showDropShadow: true)
                    SymbolView("{G/P}", size: 32, showDropShadow: true)
                    SymbolView("{T}", size: 32, showDropShadow: true)
                    SymbolView("{Q}", size: 32, showDropShadow: true)
                    SymbolView("{E}", size: 32, showDropShadow: true)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Unrecognized String")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView("{FOO}", size: 32)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
