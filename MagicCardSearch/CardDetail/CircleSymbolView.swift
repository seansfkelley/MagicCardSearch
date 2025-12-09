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

// n.b. these are the asset names for the color!


struct CircleSymbolView: View {
    let symbol: String
    let size: CGFloat

    init(_ symbol: String, size: CGFloat = 16) {
        self.symbol = symbol
        self.size = size
    }

    var body: some View {
        let cleaned = symbol.trimmingCharacters(in: CharacterSet(charactersIn: "{}")).lowercased()
        if baseSymbolCodes.contains(cleaned) {
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
    
    private func basic(_ symbol: String) -> some View {
        let color = ManaColor.fromSymbolCode(symbol) ?? .colorless
        return ZStack {
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
                    CircleSymbolView("{W}", size: 32)
                    CircleSymbolView("{U}", size: 32)
                    CircleSymbolView("{B}", size: 32)
                    CircleSymbolView("{R}", size: 32)
                    CircleSymbolView("{G}", size: 32)
                    CircleSymbolView("{C}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Generic/Colorless")
                    .font(.headline)
                HStack(spacing: 8) {
                    CircleSymbolView("{0}", size: 32)
                    CircleSymbolView("{1}", size: 32)
                    CircleSymbolView("{2}", size: 32)
                    CircleSymbolView("{3}", size: 32)
                    CircleSymbolView("{4}", size: 32)
                    CircleSymbolView("{5}", size: 32)
                }
                HStack(spacing: 8) {
                    CircleSymbolView("{6}", size: 32)
                    CircleSymbolView("{7}", size: 32)
                    CircleSymbolView("{8}", size: 32)
                    CircleSymbolView("{9}", size: 32)
                    CircleSymbolView("{10}", size: 32)
                    CircleSymbolView("{11}", size: 32)
                }
                HStack(spacing: 8) {
                    CircleSymbolView("{12}", size: 32)
                    CircleSymbolView("{13}", size: 32)
                    CircleSymbolView("{14}", size: 32)
                    CircleSymbolView("{15}", size: 32)
                    CircleSymbolView("{16}", size: 32)
                    CircleSymbolView("{20}", size: 32)
                }
                HStack(spacing: 8) {
                    CircleSymbolView("{X}", size: 32)
                    CircleSymbolView("{Y}", size: 32)
                    CircleSymbolView("{Z}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Hybrid Mana")
                    .font(.headline)
                HStack(spacing: 8) {
                    CircleSymbolView("{W/U}", size: 32)
                    CircleSymbolView("{W/B}", size: 32)
                    CircleSymbolView("{U/B}", size: 32)
                    CircleSymbolView("{U/R}", size: 32)
                    CircleSymbolView("{B/R}", size: 32)
                }
                HStack(spacing: 8) {
                    CircleSymbolView("{B/G}", size: 32)
                    CircleSymbolView("{R/W}", size: 32)
                    CircleSymbolView("{R/G}", size: 32)
                    CircleSymbolView("{G/W}", size: 32)
                    CircleSymbolView("{G/U}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Phyrexian Mana")
                    .font(.headline)
                HStack(spacing: 8) {
                    CircleSymbolView("{W/P}", size: 32)
                    CircleSymbolView("{U/P}", size: 32)
                    CircleSymbolView("{B/P}", size: 32)
                    CircleSymbolView("{R/P}", size: 32)
                    CircleSymbolView("{G/P}", size: 32)
                    CircleSymbolView("{P}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Hybrid Generic/Colored")
                    .font(.headline)
                HStack(spacing: 8) {
                    CircleSymbolView("{2/W}", size: 32)
                    CircleSymbolView("{2/U}", size: 32)
                    CircleSymbolView("{2/B}", size: 32)
                    CircleSymbolView("{2/R}", size: 32)
                    CircleSymbolView("{2/G}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Special Symbols")
                    .font(.headline)
                HStack(spacing: 8) {
                    CircleSymbolView("{S}", size: 32)
                    CircleSymbolView("{T}", size: 32)
                    CircleSymbolView("{Q}", size: 32)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
