//
//  ManaSymbolView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI
import ScryfallKit
import SVGKit

struct MtgSymbolView: View {
    private static let symbolCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200
        return cache
    }()
    
    let symbol: String
    let size: CGFloat
    let oversize: CGFloat
    
    @State private var renderedImage: UIImage?
    @State private var isLoading = true
    
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
            await loadAndRenderSVG()
        }
    }
    
    private func loadAndRenderSVG() async {
        let cacheKey = "\(symbol)_\(Int(size))" as NSString
        
        if let cachedImage = MtgSymbolView.symbolCache.object(forKey: cacheKey) {
            await MainActor.run {
                self.renderedImage = cachedImage
                self.isLoading = false
            }
            return
        }
        
        guard let symbol = try? await MTGSymbolCache.shared.getSymbol(byNotation: symbol),
              let svgUriString = symbol.svgUri,
              let url = URL(string: svgUriString) else {
            await MainActor.run { isLoading = false }
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Parse and render SVG
            guard let svgImage = SVGKImage(data: data) else {
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
            MtgSymbolView.symbolCache.setObject(uiImage, forKey: cacheKey)
            
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
                    MtgSymbolView("{W}", size: 32)
                    MtgSymbolView("{U}", size: 32)
                    MtgSymbolView("{B}", size: 32)
                    MtgSymbolView("{R}", size: 32)
                    MtgSymbolView("{G}", size: 32)
                    MtgSymbolView("{C}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Generic/Colorless")
                    .font(.headline)
                HStack(spacing: 8) {
                    MtgSymbolView("{0}", size: 32)
                    MtgSymbolView("{1}", size: 32)
                    MtgSymbolView("{2}", size: 32)
                    MtgSymbolView("{3}", size: 32)
                    MtgSymbolView("{4}", size: 32)
                    MtgSymbolView("{5}", size: 32)
                }
                HStack(spacing: 8) {
                    MtgSymbolView("{6}", size: 32)
                    MtgSymbolView("{7}", size: 32)
                    MtgSymbolView("{8}", size: 32)
                    MtgSymbolView("{9}", size: 32)
                    MtgSymbolView("{10}", size: 32)
                    MtgSymbolView("{11}", size: 32)
                }
                HStack(spacing: 8) {
                    MtgSymbolView("{12}", size: 32)
                    MtgSymbolView("{13}", size: 32)
                    MtgSymbolView("{14}", size: 32)
                    MtgSymbolView("{15}", size: 32)
                    MtgSymbolView("{16}", size: 32)
                    MtgSymbolView("{20}", size: 32)
                }
                HStack(spacing: 8) {
                    MtgSymbolView("{X}", size: 32)
                    MtgSymbolView("{Y}", size: 32)
                    MtgSymbolView("{Z}", size: 32)
                    MtgSymbolView("{∞}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Hybrid Mana")
                    .font(.headline)
                HStack(spacing: 8) {
                    MtgSymbolView("{W/U}", size: 32)
                    MtgSymbolView("{W/B}", size: 32)
                    MtgSymbolView("{U/B}", size: 32)
                    MtgSymbolView("{U/R}", size: 32)
                    MtgSymbolView("{B/R}", size: 32)
                }
                HStack(spacing: 8) {
                    MtgSymbolView("{B/G}", size: 32)
                    MtgSymbolView("{R/W}", size: 32)
                    MtgSymbolView("{R/G}", size: 32)
                    MtgSymbolView("{G/W}", size: 32)
                    MtgSymbolView("{G/U}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Phyrexian Mana")
                    .font(.headline)
                HStack(spacing: 8) {
                    MtgSymbolView("{W/P}", size: 32)
                    MtgSymbolView("{U/P}", size: 32)
                    MtgSymbolView("{B/P}", size: 32)
                    MtgSymbolView("{R/P}", size: 32)
                    MtgSymbolView("{G/P}", size: 32)
                    MtgSymbolView("{C/P}", size: 32)
                    MtgSymbolView("{H}", size: 32) // Rage Extractor
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Hybrid Generic/Colored")
                    .font(.headline)
                HStack(spacing: 8) {
                    MtgSymbolView("{2/W}", size: 32)
                    MtgSymbolView("{2/U}", size: 32)
                    MtgSymbolView("{2/B}", size: 32)
                    MtgSymbolView("{2/R}", size: 32)
                    MtgSymbolView("{2/G}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Hybrid Colorless/Colored")
                    .font(.headline)
                HStack(spacing: 8) {
                    MtgSymbolView("{C/W}", size: 32)
                    MtgSymbolView("{C/U}", size: 32)
                    MtgSymbolView("{C/B}", size: 32)
                    MtgSymbolView("{C/R}", size: 32)
                    MtgSymbolView("{C/G}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Hybrid Phyrexian")
                    .font(.headline)
                HStack(spacing: 8) {
                    MtgSymbolView("{W/U/P}", size: 32)
                    MtgSymbolView("{W/B/P}", size: 32)
                    MtgSymbolView("{U/B/P}", size: 32)
                    MtgSymbolView("{U/R/P}", size: 32)
                    MtgSymbolView("{B/R/P}", size: 32)
                }
                HStack(spacing: 8) {
                    MtgSymbolView("{B/G/P}", size: 32)
                    MtgSymbolView("{R/W/P}", size: 32)
                    MtgSymbolView("{R/G/P}", size: 32)
                    MtgSymbolView("{G/W/P}", size: 32)
                    MtgSymbolView("{G/U/P}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Special Symbols")
                    .font(.headline)
                HStack(spacing: 8) {
                    MtgSymbolView("{S}", size: 32)
                    MtgSymbolView("{T}", size: 32)
                    MtgSymbolView("{Q}", size: 32)
                    MtgSymbolView("{A}", size: 32)
                    MtgSymbolView("{E}", size: 32)
                    MtgSymbolView("{CHAOS}", size: 32)
                    MtgSymbolView("{P}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("With Drop Shadows")
                    .font(.headline)
                HStack(spacing: 8) {
                    MtgSymbolView("{W}", size: 32, showDropShadow: true)
                    MtgSymbolView("{0}", size: 32, showDropShadow: true)
                    MtgSymbolView("{U/B}", size: 32, showDropShadow: true)
                    MtgSymbolView("{G/P}", size: 32, showDropShadow: true)
                    MtgSymbolView("{T}", size: 32, showDropShadow: true)
                    MtgSymbolView("{Q}", size: 32, showDropShadow: true)
                    MtgSymbolView("{E}", size: 32, showDropShadow: true)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Unrecognized String")
                    .font(.headline)
                HStack(spacing: 8) {
                    MtgSymbolView("{FOO}", size: 32)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
