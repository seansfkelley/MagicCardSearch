//
//  ManaSymbolView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI

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
private enum ManaColor: String {
    case white = "White"
    case blue = "Blue"
    case black = "Black"
    case red = "Red"
    case green = "Green"
    case colorless = "Colorless"

    static func fromSymbolCode(_ s: String) -> ManaColor? {
        return switch s {
        case "w": .white
        case "u": .blue
        case "b": .black
        case "r": .red
        case "g": .green
        case "c": .colorless
        default: nil
        }
    }
}

struct CircleSymbol: View {
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
                .fill(Color(color.rawValue))
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
                .fill(Color(color.rawValue))
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
                            .init(color: Color(leftColor.rawValue), location: 0.0),
                            .init(color: Color(leftColor.rawValue), location: 0.5),
                            .init(color: Color(rightColor.rawValue), location: 0.5),
                            .init(color: Color(rightColor.rawValue), location: 1.0),
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
                    CircleSymbol("{W}", size: 32)
                    CircleSymbol("{U}", size: 32)
                    CircleSymbol("{B}", size: 32)
                    CircleSymbol("{R}", size: 32)
                    CircleSymbol("{G}", size: 32)
                    CircleSymbol("{C}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Generic/Colorless")
                    .font(.headline)
                HStack(spacing: 8) {
                    CircleSymbol("{0}", size: 32)
                    CircleSymbol("{1}", size: 32)
                    CircleSymbol("{2}", size: 32)
                    CircleSymbol("{3}", size: 32)
                    CircleSymbol("{4}", size: 32)
                    CircleSymbol("{5}", size: 32)
                }
                HStack(spacing: 8) {
                    CircleSymbol("{6}", size: 32)
                    CircleSymbol("{7}", size: 32)
                    CircleSymbol("{8}", size: 32)
                    CircleSymbol("{9}", size: 32)
                    CircleSymbol("{10}", size: 32)
                    CircleSymbol("{11}", size: 32)
                }
                HStack(spacing: 8) {
                    CircleSymbol("{12}", size: 32)
                    CircleSymbol("{13}", size: 32)
                    CircleSymbol("{14}", size: 32)
                    CircleSymbol("{15}", size: 32)
                    CircleSymbol("{16}", size: 32)
                    CircleSymbol("{20}", size: 32)
                }
                HStack(spacing: 8) {
                    CircleSymbol("{X}", size: 32)
                    CircleSymbol("{Y}", size: 32)
                    CircleSymbol("{Z}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Hybrid Mana")
                    .font(.headline)
                HStack(spacing: 8) {
                    CircleSymbol("{W/U}", size: 32)
                    CircleSymbol("{W/B}", size: 32)
                    CircleSymbol("{U/B}", size: 32)
                    CircleSymbol("{U/R}", size: 32)
                    CircleSymbol("{B/R}", size: 32)
                }
                HStack(spacing: 8) {
                    CircleSymbol("{B/G}", size: 32)
                    CircleSymbol("{R/W}", size: 32)
                    CircleSymbol("{R/G}", size: 32)
                    CircleSymbol("{G/W}", size: 32)
                    CircleSymbol("{G/U}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Phyrexian Mana")
                    .font(.headline)
                HStack(spacing: 8) {
                    CircleSymbol("{W/P}", size: 32)
                    CircleSymbol("{U/P}", size: 32)
                    CircleSymbol("{B/P}", size: 32)
                    CircleSymbol("{R/P}", size: 32)
                    CircleSymbol("{G/P}", size: 32)
                    CircleSymbol("{P}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Hybrid Generic/Colored")
                    .font(.headline)
                HStack(spacing: 8) {
                    CircleSymbol("{2/W}", size: 32)
                    CircleSymbol("{2/U}", size: 32)
                    CircleSymbol("{2/B}", size: 32)
                    CircleSymbol("{2/R}", size: 32)
                    CircleSymbol("{2/G}", size: 32)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Special Symbols")
                    .font(.headline)
                HStack(spacing: 8) {
                    CircleSymbol("{S}", size: 32)
                    CircleSymbol("{T}", size: 32)
                    CircleSymbol("{Q}", size: 32)
                    CircleSymbol("{E}", size: 32)
                    CircleSymbol("{CHAOS}", size: 32)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
