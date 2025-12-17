//
//  ManaSymbolView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI
import ScryfallKit
import SVGKit

struct SymbolView: View {
    // AFAICT Scryfall's symbology doesn't tell us about this, so we need to hardcode it to know
    // what to do about drop shadows.
    private static let symbolsWithoutBackgrounds = Set([
        SymbolCode("E"), SymbolCode("CHAOS"), SymbolCode("P"), SymbolCode("H"),
    ])
    
    private static let svgDataCache: any Cache<SymbolCode, Data> = {
        let memoryCache = MemoryCache<SymbolCode, Data>(expiration: .interval(60 * 60 * 24))
        return if let diskCache = DiskCache<SymbolCode, Data>(
            name: "SymbolSvg",
            expiration: .interval(60 * 60 * 24 * 30),
        ) {
            HybridCache(memoryCache: memoryCache, diskCache: diskCache)
        } else {
            memoryCache
        }
    }()
    
    private static var renderedImageCache: any Cache<SymbolCode, UIImage> = {
        return MemoryCache(expiration: .never)
    }()
    
    let symbol: SymbolCode
    let size: CGFloat
    let oversize: CGFloat
    let showDropShadow: Bool
    
    @State private var imageResult: LoadableResult<(Card.Symbol, UIImage)> = .unloaded
    
    init(
        _ symbol: String,
        size: CGFloat = 16,
        oversize: CGFloat? = nil,
        showDropShadow: Bool = false
    ) {
        self.symbol = SymbolCode(symbol)
        self.size = size
        self.oversize = oversize ?? size * 1.25
        self.showDropShadow = showDropShadow
    }
    
    var targetSize: CGFloat {
        if case .success((let symbol, _)) = imageResult.latestResult {
            symbol.hybrid || symbol.phyrexian ? oversize : size
        } else {
            size
        }
    }
    
    var body: some View {
        ZStack {
            if showDropShadow && !Self.symbolsWithoutBackgrounds.contains(symbol) {
                Circle()
                    .fill(Color.black)
                    .frame(width: targetSize, height: targetSize)
                    .offset(x: -1, y: 1)
            }
            
            if case .success((_, let image)) = imageResult.latestResult {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: targetSize, height: targetSize)
            } else if case .failure = imageResult.latestResult {
                Text(symbol.normalized)
                    .font(.system(size: targetSize * 0.5))
                    .foregroundStyle(.secondary)
                    .frame(width: targetSize, height: targetSize)
            } else {
                Circle()
                    .fill(.secondary.opacity(0.2))
                    .frame(width: targetSize, height: targetSize)
            }
        }
        .task {
            await loadAndRender()
        }
    }
    
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
        
        let symbolResult = await ScryfallMetadataCache.shared.symbol(self.symbol)
        guard case .success(let symbolData) = symbolResult,
              let svgUriString = symbolData.svgUri,
              let url = URL(string: svgUriString) else {
            await MainActor.run {
                imageResult = .loaded(.failure(NSError(domain: "SymbolView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get symbol metadata"])))
            }
            return
        }
        
        if let renderedImage = Self.renderedImageCache[symbol] {
            await MainActor.run {
                self.imageResult = .loaded(.success((symbolData, renderedImage)))
            }
            return
        }
        
        do {
            let svgData = try await Self.svgDataCache.get(forKey: self.symbol) {
                let (data, _) = try await URLSession.shared.data(from: url)
                return data
            }
            
            guard let svgImage = SVGKImage(data: svgData) else {
                await MainActor.run {
                    imageResult = .loaded(.failure(NSError(domain: "SymbolView", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create SVG image"])))
                }
                return
            }
            
            guard let uiImage = svgImage.uiImage else {
                await MainActor.run {
                    imageResult = .loaded(.failure(NSError(domain: "SymbolView", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to render SVG to UIImage"])))
                }
                return
            }
            
            Self.renderedImageCache[symbol] = uiImage
            
            await MainActor.run {
                self.imageResult = .loaded(.success((symbolData, uiImage)))
            }
        } catch {
            await MainActor.run {
                self.imageResult = .loaded(.failure(error))
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
