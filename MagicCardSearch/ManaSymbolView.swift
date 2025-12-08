//
//  ManaSymbolView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI

struct ManaSymbolView: View {
    let symbol: String
    let size: CGFloat
    
    init(_ symbol: String, size: CGFloat = 16) {
        self.symbol = symbol
        self.size = size
    }
    
    var body: some View {
        if let imageName = symbolToImageName(symbol) {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            // Fallback for unknown symbols
            Text(symbol)
                .font(.system(size: size * 0.6))
                .foregroundStyle(.secondary)
        }
    }
    
    private func symbolToImageName(_ symbol: String) -> String? {
        // Remove curly braces
        let cleaned = symbol.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
        
        // Map Scryfall mana symbols to image names
        switch cleaned.uppercased() {
        // Basic mana
        case "W": return "mana_w"
        case "U": return "mana_u"
        case "B": return "mana_b"
        case "R": return "mana_r"
        case "G": return "mana_g"
        case "C": return "mana_c"
            
        // Colorless/generic
        case "0": return "mana_0"
        case "1": return "mana_1"
        case "2": return "mana_2"
        case "3": return "mana_3"
        case "4": return "mana_4"
        case "5": return "mana_5"
        case "6": return "mana_6"
        case "7": return "mana_7"
        case "8": return "mana_8"
        case "9": return "mana_9"
        case "10": return "mana_10"
        case "11": return "mana_11"
        case "12": return "mana_12"
        case "13": return "mana_13"
        case "14": return "mana_14"
        case "15": return "mana_15"
        case "16": return "mana_16"
        case "20": return "mana_20"
        case "X": return "mana_x"
        case "Y": return "mana_y"
        case "Z": return "mana_z"
            
        // Hybrid mana
        case "W/U", "WU": return "mana_wu"
        case "W/B", "WB": return "mana_wb"
        case "U/B", "UB": return "mana_ub"
        case "U/R", "UR": return "mana_ur"
        case "B/R", "BR": return "mana_br"
        case "B/G", "BG": return "mana_bg"
        case "R/W", "RW": return "mana_rw"
        case "R/G", "RG": return "mana_rg"
        case "G/W", "GW": return "mana_gw"
        case "G/U", "GU": return "mana_gu"
            
        // Phyrexian mana
        case "W/P", "WP": return "mana_wp"
        case "U/P", "UP": return "mana_up"
        case "B/P", "BP": return "mana_bp"
        case "R/P", "RP": return "mana_rp"
        case "G/P", "GP": return "mana_gp"
        case "P": return "mana_p"
            
        // Hybrid generic/colored
        case "2/W": return "mana_2w"
        case "2/U": return "mana_2u"
        case "2/B": return "mana_2b"
        case "2/R": return "mana_2r"
        case "2/G": return "mana_2g"
            
        // Special
        case "S": return "mana_s"
        case "T": return "mana_tap"
        case "Q": return "mana_untap"
        case "E": return "mana_e"
        case "CHAOS": return "mana_chaos"
            
        default:
            return nil
        }
    }
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
                ManaSymbolView(symbol, size: size)
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
