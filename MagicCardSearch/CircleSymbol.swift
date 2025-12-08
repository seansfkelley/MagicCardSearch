//
//  ManaSymbolView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI

private let baseManaNames = Set([
    // Colors/colorless mana
    "w", "u", "b", "r", "g", "c",
    
    // Generic mana
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10",
    "11", "12", "13", "14", "15", "16", "20", "1000000", "x", "y", "z",
    
    // Phyrexian mana, which never appears alone but is nevertheless a base symbol type
    "p",
    
    // Other symbols
    "s", "t", "q", "e", "chaos",
])

// n.b. these are the asset names for the color!
private enum ManaColor: String {
    case white = "White"
    case blue = "Blue"
    case black = "Black"
    case red = "Red"
    case green = "Green"
    case colorless = "Colorless"
    
    static func fromShorthand(_ s: String) -> ManaColor? {
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
        if baseManaNames.contains(cleaned) {
            let color = ManaColor.fromShorthand(cleaned) ?? .colorless
            ZStack {
                Circle()
                    .fill(Color(color.rawValue))
                    .frame(width: size, height: size)
                
                Image(cleaned)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.8, height: size * 0.8)
            }
        } else {
            // fallback; should never happen
            Text(symbol)
                .font(.system(size: size * 0.6))
                .foregroundStyle(.secondary)
        }
    }

//    private func symbolToImageName(_ symbol: String) -> String? {
//        return switch cleaned.uppercased() {
//        case "W/U", "WU": "wu"
//        case "W/B", "WB": "wb"
//        case "U/B", "UB": "ub"
//        case "U/R", "UR": "ur"
//        case "B/R", "BR": "br"
//        case "B/G", "BG": "bg"
//        case "R/W", "RW": "rw"
//        case "R/G", "RG": "rg"
//        case "G/W", "GW": "gw"
//        case "G/U", "GU": "gu"
//
//        // Phyrexian mana
//        case "W/P", "WP": "wp"
//        case "U/P", "UP": "up"
//        case "B/P", "BP": "bp"
//        case "R/P", "RP": "rp"
//        case "G/P", "GP": "gp"
//        case "P": "p"
//
//        // Hybrid generic/colored
//        case "2/W": "2w"
//        case "2/U": "2u"
//        case "2/B": "2b"
//        case "2/R": "2r"
//        case "2/G": "2g"
//
//        }
//    }
}

struct ManaCostView: View {
    let manaCost: String
    let size: CGFloat

    init(_ manaCost: String, size: CGFloat = 16) {
        self.manaCost = manaCost
        self.size = size
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(parseManaCost(manaCost), id: \.self) { symbol in
                CircleSymbol(symbol, size: size)
            }
        }
    }

    private func parseManaCost(_ cost: String) -> [String] {
        var symbols: [String] = []
        var currentSymbol = ""
        var inBraces = false

        for char in cost {
            if char == "{" {
                inBraces = true
                currentSymbol = "{"
            } else if char == "}" {
                currentSymbol += "}"
                symbols.append(currentSymbol)
                currentSymbol = ""
                inBraces = false
            } else if inBraces {
                currentSymbol += String(char)
            }
        }

        return symbols
    }
}

#Preview("All Mana Symbols") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            // Basic mana
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

            Divider()

            // Generic/Colorless
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

            Divider()

            // Hybrid mana
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

            Divider()

            // Phyrexian mana
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

            Divider()

            // Hybrid generic/colored
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

            Divider()

            // Special symbols
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

            Divider()

            // Example mana costs
            VStack(alignment: .leading, spacing: 8) {
                Text("Example Mana Costs")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    ManaCostView("{3}{U}{U}", size: 24)
                    ManaCostView("{2}{W}{U}", size: 24)
                    ManaCostView("{X}{R}{R}", size: 24)
                    ManaCostView("{W/U}{W/U}{W/U}", size: 24)
                    ManaCostView("{5}{B}{B}{B}", size: 24)
                }
            }
        }
        .padding()
    }
}
