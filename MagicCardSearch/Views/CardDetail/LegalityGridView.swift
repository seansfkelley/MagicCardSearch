//
//  LegalityGridView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI

// The weird order here is because the column view goes English reading order, and it's a lot easier
// to get it to do the right thing like this than trying to flow it down the columns.
private enum Format: String, CaseIterable {
    case standard = "Standard"
    case alchemy = "Alchemy"
    case pioneer = "Pioneer"
    case historic = "Historic"
    case modern = "Modern"
    case brawl = "Brawl"
    case legacy = "Legacy"
    case timeless = "Timeless"
    case vintage = "Vintage"
    case pauper = "Pauper"
    case commander = "Commander"
    case penny = "Penny"
    case oathbreaker = "Oathbreaker"
    
    var apiKey: String {
        return String(describing: self)
    }
}

private enum Legality: String {
    case legal = "Legal"
    case notLegal = "Not Legal"
    case restricted = "Restricted"
    case banned = "Banned"
    case unknown = "Unknown"
    
    static func fromApiValue(_ s: String) -> Legality? {
        return switch s.lowercased() {
        case "legal": .legal
        case "not_legal": .notLegal
        case "restricted": .restricted
        case "banned": .banned
        default: .unknown
        }
    }
}

struct LegalityGridView: View {
    let legalities: [String: String]
    let isGameChanger: Bool
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ], spacing: 12) {
            ForEach(Format.allCases, id: \.self) { format in
                if let apiLegality = legalities[format.apiKey], let legality = Legality.fromApiValue(apiLegality) {
                    LegalityItemView(format: format, legality: legality, isGameChanger: isGameChanger)
                } else {
                    LegalityItemView(format: format, legality: .unknown, isGameChanger: isGameChanger)
                }
            }
        }
    }
}

private struct LegalityItemView: View {
    let format: Format
    let legality: Legality
    let isGameChanger: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(legalityColor)
                .frame(width: 80, height: 28)
                .overlay(
                    Text(legalityDisplayText.uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                )
            
            Text(format.rawValue)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var legalityDisplayText: String {
        if format == .commander && legality == .legal && isGameChanger {
            return "Legal/GC"
        } else {
            return legality.rawValue
        }
    }
    
    private var legalityColor: Color {
        if format == .commander && legality == .legal && isGameChanger {
            // TODO: A different color.
            return .green
        } else {
            return switch legality {
            case .legal: .green
            case .notLegal, .unknown: .gray
            case .restricted: .orange
            case .banned: .red
            }
        }
    }
}
