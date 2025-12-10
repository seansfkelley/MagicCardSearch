//
//  ManaSymbolView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI

enum ManaColor: String {
    case white = "WhiteManaColor"
    case blue = "BlueManaColor"
    case black = "BlackManaColor"
    case red = "RedManaColor"
    case green = "GreenManaColor"
    case colorless = "ColorlessManaColor"

    static func fromSymbolCode(_ s: String) -> ManaColor? {
        return switch s.lowercased() {
        case "w": .white
        case "u": .blue
        case "b": .black
        case "r": .red
        case "g": .green
        case "c": .colorless
        default: nil
        }
    }
    
    var uiColor: Color {
        return Color(self.rawValue)
    }
}


private let baseSymbolCodes = Set([
    // Colors/colorless mana
    "w", "u", "b", "r", "g", "c",

    // Generic mana
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10",
    "11", "12", "13", "14", "15", "16", "20", "1000000", "x", "y", "z",

    // Phyrexian mana, which never appears alone but is nevertheless a base symbol type
    "p",

    // Other symbols
    "s", "t", "q"
])

private let noncircledSymbolCodes = Set(["e", "chaos"])

struct MtgSymbolView: View {
    let symbol: String
    let size: CGFloat
    let showDropShadow: Bool

    init(_ symbol: String, size: CGFloat = 16, showDropShadow: Bool = false) {
        self.symbol = symbol
        self.size = size
        self.showDropShadow = showDropShadow
    }

    var body: some View {
        let cleaned = symbol.trimmingCharacters(in: CharacterSet(charactersIn: "{}")).lowercased()
        if noncircledSymbolCodes.contains(cleaned) {
            noncircled(cleaned)
        } else if baseSymbolCodes.contains(cleaned) {
            basic(cleaned)
        } else {
            let parts = cleaned.split(separator: "/")
            if parts.count == 2 {
                let left = String(parts[0])
                let right = String(parts[1])

                if baseSymbolCodes.contains(left) && baseSymbolCodes.contains(right) {
                    if right == "p", let color = ManaColor.fromSymbolCode(left) {
                        phyrexian(color)
                    } else {
                        hybrid(left, right)
                    }
                } else {
                    unknown(cleaned)
                }
            } else {
                unknown(cleaned)
            }
        }
    }
    
    private func noncircled(_ symbol: String) -> some View {
        return Image(symbol)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size * 0.8, height: size * 0.8)
    }
    
    private func basic(_ symbol: String) -> some View {
        let color = ManaColor.fromSymbolCode(symbol) ?? .colorless
        return ZStack {
            if showDropShadow {
                Circle()
                    .fill(.black)
                    .frame(width: size, height: size)
                    .offset(x: -1, y: 1)
            }
            
            Circle()
                .fill(color.uiColor)
                .frame(width: size, height: size)
            
            Image(symbol)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.8, height: size * 0.8)
        }
    }

    private func phyrexian(_ color: ManaColor) -> some View {
        return ZStack {
            if showDropShadow {
                Circle()
                    .fill(.black)
                    .frame(width: size, height: size)
                    .offset(x: -1, y: 1)
            }
            
            Circle()
                .fill(color.uiColor)
                .frame(width: size, height: size)

            Image("p")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.8, height: size * 0.8)
        }
    }

    private func hybrid(_ left: String, _ right: String) -> some View {
        let leftColor = ManaColor.fromSymbolCode(left) ?? .colorless
        let rightColor = ManaColor.fromSymbolCode(right) ?? .colorless

        return ZStack {
            if showDropShadow {
                Circle()
                    .fill(.black)
                    .frame(width: size, height: size)
                    .offset(x: -1, y: 1)
            }
            
            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: leftColor.uiColor, location: 0.0),
                            .init(color: leftColor.uiColor, location: 0.5),
                            .init(color: rightColor.uiColor, location: 0.5),
                            .init(color: rightColor.uiColor, location: 1.0),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Image(left)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.4, height: size * 0.4)
                .offset(x: -size * 0.16, y: -size * 0.16)

            Image(right)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.4, height: size * 0.4)
                .offset(x: size * 0.175, y: size * 0.175)
        }
    }

    private func unknown(_ symbol: String) -> some View {
        Text(symbol)
            .font(.system(size: size * 0.6))
            .foregroundStyle(.secondary)
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
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
