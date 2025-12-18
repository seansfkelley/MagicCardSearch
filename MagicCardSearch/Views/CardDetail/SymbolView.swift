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
    
    private struct RenderedImageCacheKey: Hashable {
        let symbol: SymbolCode
        let targetSize: CGFloat
    }
    
    private static var renderedImageCache: any Cache<RenderedImageCacheKey, UIImage> = {
        return MemoryCache(expiration: .never)
    }()
    
    private var renderedImageCacheKey: RenderedImageCacheKey {
        RenderedImageCacheKey(symbol: symbol, targetSize: targetSize)
    }
    
    let symbol: SymbolCode
    let size: CGFloat
    let oversize: CGFloat
    let showDropShadow: Bool
    
    init(
        _ symbol: SymbolCode,
        size: CGFloat = 16,
        oversize: CGFloat? = nil,
        showDropShadow: Bool = false
    ) {
        self.symbol = symbol
        self.size = size
        self.oversize = oversize ?? size * 1.25
        self.showDropShadow = showDropShadow
    }
    
    private var targetSize: CGFloat {
        symbol.isOversized ?? false ? oversize : size
    }
    
    var body: some View {
        ZStack {
            if showDropShadow && !Self.symbolsWithoutBackgrounds.contains(symbol) {
                Circle()
                    .fill(Color.black)
                    .frame(width: targetSize, height: targetSize)
                    .offset(x: -1, y: 1)
            }
            
            if let image = renderImage() {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: targetSize, height: targetSize)
            } else {
                Text(symbol.normalized)
                    .font(.system(size: targetSize * 0.5))
                    .foregroundStyle(.secondary)
                    .frame(width: targetSize, height: targetSize)
            }
        }
    }
    
    private func renderImage() -> UIImage? {
        if let cachedImage = Self.renderedImageCache[renderedImageCacheKey] {
            return cachedImage
        }
        
        guard let svgData = ScryfallMetadataCache.shared.symbolSvg[symbol] else {
            return nil
        }
        
        guard let svgImage = SVGKImage(data: svgData) else {
            return nil
        }
        
        let originalSize = svgImage.size
        let scale = targetSize / max(originalSize.width, originalSize.height)
        let scaledSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )
        
        // n.b. we scale in SVG space, not in UIImage space, to get a smoother result. This means
        // we clog the memory cache with duplicates for every size, but we use pretty consistent
        // sizes so it should be fine.
        svgImage.size = scaledSize
        
        guard let uiImage = svgImage.uiImage else {
            return nil
        }
        
        Self.renderedImageCache[renderedImageCacheKey] = uiImage
        
        return uiImage
    }
}

#Preview("All Mana Symbols") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Basic Mana")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView(SymbolCode("{W}"), size: 32)
                    SymbolView(SymbolCode("{U}"), size: 32)
                    SymbolView(SymbolCode("{B}"), size: 32)
                    SymbolView(SymbolCode("{R}"), size: 32)
                    SymbolView(SymbolCode("{G}"), size: 32)
                    SymbolView(SymbolCode("{C}"), size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Generic/Colorless")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView(SymbolCode("{0}"), size: 32)
                    SymbolView(SymbolCode("{1}"), size: 32)
                    SymbolView(SymbolCode("{2}"), size: 32)
                    SymbolView(SymbolCode("{3}"), size: 32)
                    SymbolView(SymbolCode("{4}"), size: 32)
                    SymbolView(SymbolCode("{5}"), size: 32)
                }
                HStack(spacing: 8) {
                    SymbolView(SymbolCode("{6}"), size: 32)
                    SymbolView(SymbolCode("{7}"), size: 32)
                    SymbolView(SymbolCode("{8}"), size: 32)
                    SymbolView(SymbolCode("{9}"), size: 32)
                    SymbolView(SymbolCode("{10}"), size: 32)
                    SymbolView(SymbolCode("{11}"), size: 32)
                }
                HStack(spacing: 8) {
                    SymbolView(SymbolCode("{12}"), size: 32)
                    SymbolView(SymbolCode("{13}"), size: 32)
                    SymbolView(SymbolCode("{14}"), size: 32)
                    SymbolView(SymbolCode("{15}"), size: 32)
                    SymbolView(SymbolCode("{16}"), size: 32)
                    SymbolView(SymbolCode("{20}"), size: 32)
                }
                HStack(spacing: 8) {
                    SymbolView(SymbolCode("{X}"), size: 32)
                    SymbolView(SymbolCode("{Y}"), size: 32)
                    SymbolView(SymbolCode("{Z}"), size: 32)
                    SymbolView(SymbolCode("{∞}"), size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Hybrid Mana")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView(SymbolCode("{W/U}"), size: 32)
                    SymbolView(SymbolCode("{W/B}"), size: 32)
                    SymbolView(SymbolCode("{U/B}"), size: 32)
                    SymbolView(SymbolCode("{U/R}"), size: 32)
                    SymbolView(SymbolCode("{B/R}"), size: 32)
                }
                HStack(spacing: 8) {
                    SymbolView(SymbolCode("{B/G}"), size: 32)
                    SymbolView(SymbolCode("{R/W}"), size: 32)
                    SymbolView(SymbolCode("{R/G}"), size: 32)
                    SymbolView(SymbolCode("{G/W}"), size: 32)
                    SymbolView(SymbolCode("{G/U}"), size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Phyrexian Mana")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView(SymbolCode("{W/P}"), size: 32)
                    SymbolView(SymbolCode("{U/P}"), size: 32)
                    SymbolView(SymbolCode("{B/P}"), size: 32)
                    SymbolView(SymbolCode("{R/P}"), size: 32)
                    SymbolView(SymbolCode("{G/P}"), size: 32)
                    SymbolView(SymbolCode("{C/P}"), size: 32)
                    SymbolView(SymbolCode("{H}"), size: 32) // Rage Extractor
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Hybrid Generic/Colored")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView(SymbolCode("{2/W}"), size: 32)
                    SymbolView(SymbolCode("{2/U}"), size: 32)
                    SymbolView(SymbolCode("{2/B}"), size: 32)
                    SymbolView(SymbolCode("{2/R}"), size: 32)
                    SymbolView(SymbolCode("{2/G}"), size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Hybrid Colorless/Colored")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView(SymbolCode("{C/W}"), size: 32)
                    SymbolView(SymbolCode("{C/U}"), size: 32)
                    SymbolView(SymbolCode("{C/B}"), size: 32)
                    SymbolView(SymbolCode("{C/R}"), size: 32)
                    SymbolView(SymbolCode("{C/G}"), size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Hybrid Phyrexian")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView(SymbolCode("{W/U/P}"), size: 32)
                    SymbolView(SymbolCode("{W/B/P}"), size: 32)
                    SymbolView(SymbolCode("{U/B/P}"), size: 32)
                    SymbolView(SymbolCode("{U/R/P}"), size: 32)
                    SymbolView(SymbolCode("{B/R/P}"), size: 32)
                }
                HStack(spacing: 8) {
                    SymbolView(SymbolCode("{B/G/P}"), size: 32)
                    SymbolView(SymbolCode("{R/W/P}"), size: 32)
                    SymbolView(SymbolCode("{R/G/P}"), size: 32)
                    SymbolView(SymbolCode("{G/W/P}"), size: 32)
                    SymbolView(SymbolCode("{G/U/P}"), size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Special Symbols")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView(SymbolCode("{S}"), size: 32)
                    SymbolView(SymbolCode("{T}"), size: 32)
                    SymbolView(SymbolCode("{Q}"), size: 32)
                    SymbolView(SymbolCode("{A}"), size: 32)
                    SymbolView(SymbolCode("{E}"), size: 32)
                    SymbolView(SymbolCode("{CHAOS}"), size: 32)
                    SymbolView(SymbolCode("{P}"), size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("With Drop Shadows")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView(SymbolCode("{W}"), size: 32, showDropShadow: true)
                    SymbolView(SymbolCode("{0}"), size: 32, showDropShadow: true)
                    SymbolView(SymbolCode("{U/B}"), size: 32, showDropShadow: true)
                    SymbolView(SymbolCode("{G/P}"), size: 32, showDropShadow: true)
                    SymbolView(SymbolCode("{T}"), size: 32, showDropShadow: true)
                    SymbolView(SymbolCode("{Q}"), size: 32, showDropShadow: true)
                    SymbolView(SymbolCode("{E}"), size: 32, showDropShadow: true)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Unrecognized String")
                    .font(.headline)
                HStack(spacing: 8) {
                    SymbolView(SymbolCode("{FOO}"), size: 32)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
