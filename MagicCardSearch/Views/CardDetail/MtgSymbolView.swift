//
//  ManaSymbolView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI
import ScryfallKit

private let bareSymbolCodes = Set(["E", "CHAOS", "TK"])
// Xcode does not like these assets having crazy names.
private let aliasedAssetNames = [
    "∞": "infinity",
    "½": "half",
]

enum MtgSymbol {
    case bare(String)
    case generic(String) // Includes generic mana, tap, etc.
    case basic(Card.Color)
    case hybrid(Card.Color, Card.Color)
    case genericHybrid(String, Card.Color) // Left side is always 2, but might as well future-proof...
    case phyrexian(Card.Color)
    case phyrexianHybrid(Card.Color, Card.Color)
    
    var isOversized: Bool {
        switch self {
        case .hybrid, .genericHybrid, .phyrexian, .phyrexianHybrid: true
        default: false
        }
    }
    
    static func fromString(_ symbol: String) -> MtgSymbol {
        let cleaned = symbol.trimmingCharacters(in: CharacterSet(charactersIn: "{}")).uppercased()
        
        if bareSymbolCodes.contains(cleaned) {
            return .bare(cleaned.lowercased())
        }
        
        if let basic = Card.Color(rawValue: cleaned) {
            return .basic(basic)
        }
        
        if cleaned == "P" {
            return .phyrexian(.C)
        }
        
        let parts = cleaned.split(separator: "/")
        if parts.count == 3 && parts.last == "P" {
            if let left = Card.Color(rawValue: String(parts[0])), let right = Card.Color(rawValue: String(parts[1])) {
                return .phyrexianHybrid(left, right)
            }
        }
        
        if parts.count == 2 {
            let left = Card.Color(rawValue: String(parts[0]))
            let right = Card.Color(rawValue: String(parts[1]))
            
            if left == nil, let right = right {
                return .genericHybrid(String(parts[0]), right)
            }
            
            if let left = left, parts[1] == "P" {
                return .phyrexian(left)
            }
            
            if let left = left, let right = right {
                return .hybrid(left, right)
            }
        }
        
        return .generic(cleaned.lowercased())
    }
}

struct MtgSymbolView: View {
    let symbol: MtgSymbol
    let size: CGFloat
    let oversize: CGFloat
    let showDropShadow: Bool

    init?(
        _ symbol: String,
        size: CGFloat = 16,
        oversize: CGFloat? = nil,
        showDropShadow: Bool = false
    ) {
        self.init(MtgSymbol.fromString(symbol), size: size, oversize: oversize, showDropShadow: showDropShadow)
    }
    
    init(
        _ symbol: MtgSymbol,
        size: CGFloat = 16,
        oversize: CGFloat? = nil,
        showDropShadow: Bool = false
    ) {
        self.symbol = symbol
        self.size = size
        self.oversize = floor(oversize ?? size * 1.25)
        self.showDropShadow = showDropShadow
    }

    var body: some View {
        switch symbol {
        case .bare(let symbol): bare(symbol)
        case .generic(let symbol): generic(symbol)
        case .basic(let color): basic(color)
        case .hybrid(let left, let right): hybrid(left, right)
        case .genericHybrid(let left, let right): genericHybrid(left, right)
        case .phyrexian(let color): phyrexian(color)
        case .phyrexianHybrid(let left, let right): phyrexianHybrid(left, right)
        }
    }
    
    private func bare(_ symbol: String) -> some View {
        Image(aliasedAssetNames[symbol] ?? symbol)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size * 0.8, height: size * 0.8)
    }
    
    private func generic(_ symbol: String) -> some View {
        regular(Card.Color.C) {
            Image(aliasedAssetNames[symbol] ?? symbol)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.8, height: size * 0.8)
        }
    }
    
    private func basic(_ color: Card.Color) -> some View {
        regular(color) {
            Image(color.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.8, height: size * 0.8)
        }
    }

    private func hybrid(_ left: Card.Color, _ right: Card.Color) -> some View {
        split(left, right) {
            Image(left.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: oversize * 0.4, height: oversize * 0.4)
                .offset(x: -oversize * 0.16, y: -oversize * 0.16)

            Image(right.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: oversize * 0.4, height: oversize * 0.4)
                .offset(x: oversize * 0.175, y: oversize * 0.175)
        }
    }
    
    private func genericHybrid(_ left: String, _ right: Card.Color) -> some View {
        split(Card.Color.C, right, saturated: right == .B) {
            Image(aliasedAssetNames[left] ?? left)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: oversize * 0.4, height: oversize * 0.4)
                .offset(x: -oversize * 0.16, y: -oversize * 0.16)

            Image(right.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: oversize * 0.4, height: oversize * 0.4)
                .offset(x: oversize * 0.175, y: oversize * 0.175)
        }
    }
    
    private func phyrexian(_ color: Card.Color) -> some View {
        regular(color, oversize: true, saturated: true) {
            Image("p")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: oversize, height: oversize)
                .clipShape(.circle)
        }
    }
    
    private func phyrexianHybrid(_ left: Card.Color, _ right: Card.Color) -> some View {
        split(left, right, saturated: true) {
            Image("p")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: oversize * 0.5, height: oversize * 0.5)
                .offset(x: -oversize * 0.16, y: -oversize * 0.16)

            Image("p")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: oversize * 0.5, height: oversize * 0.5)
                .offset(x: oversize * 0.175, y: oversize * 0.175)
        }
    }

    private func unknown(_ symbol: String) -> some View {
        Text(symbol)
            .font(.system(size: size * 0.6))
            .foregroundStyle(.secondary)
    }
    
    private func regular(
        _ color: Card.Color,
        oversize isOversized: Bool = false,
        saturated isSaturated: Bool = false,
        @ViewBuilder image: () -> some View,
    ) -> some View {
        let actualSize = isOversized ? oversize : size
        let actualColor = isSaturated ? color.saturatedUiColor : color.basicUiColor
        
        return ZStack {
            if showDropShadow {
                Circle()
                    .fill(.black)
                    .frame(width: actualSize, height: actualSize)
                    .offset(x: -1, y: 1)
            }
            
            Circle()
                .fill(actualColor)
                .frame(width: actualSize, height: actualSize)
            
            image()
        }
    }
    
    private func split<Content: View>(
        _ left: Card.Color,
        _ right: Card.Color,
        saturated isSaturated: Bool = false,
        @ViewBuilder images: () -> Content
    ) -> some View {
        let actualLeftColor = isSaturated ? left.saturatedUiColor : left.basicUiColor
        let actualRightColor = isSaturated ? right.saturatedUiColor : right.basicUiColor
        
        return ZStack {
            if showDropShadow {
                Circle()
                    .fill(.black)
                    .frame(width: oversize, height: oversize)
                    .offset(x: -1, y: 1)
            }
            
            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: actualLeftColor, location: 0.0),
                            .init(color: actualLeftColor, location: 0.5),
                            .init(color: actualRightColor, location: 0.5),
                            .init(color: actualRightColor, location: 1.0),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: oversize, height: oversize)
            
            images()
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
                    MtgSymbolView("{P}", size: 32)
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
                    MtgSymbolView("{E}", size: 32)
                    MtgSymbolView("{CHAOS}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("With Drop Shadows")
                    .font(.headline)
                HStack(spacing: 8) {
                    MtgSymbolView("{W}", size: 32, showDropShadow: true)
                    MtgSymbolView("{0}", size: 32, showDropShadow: true)
                    MtgSymbolView("{B/U}", size: 32, showDropShadow: true)
                    MtgSymbolView("{G/P}", size: 32, showDropShadow: true)
                    MtgSymbolView("{T}", size: 32, showDropShadow: true)
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
