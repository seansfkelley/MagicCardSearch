//
//  Format+label.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-10.
//
import ScryfallKit

extension Format {
    var label: String {
        return switch self {
        case .standard: "Standard"
        case .historic: "Historic"
        case .pioneer: "Pioneer"
        case .modern: "Modern"
        case .legacy: "Legacy"
        case .pauper: "Pauper"
        case .vintage: "Vintage"
        case .penny: "Penny"
        case .commander: "Commander"
        case .brawl: "Brawl"
        case .future: "Future"
        case .timeless: "Timeless"
        case .gladiator: "Gladiator"
        case .oathbreaker: "Oathbreaker"
        case .standardbrawl: "Standard Brawl"
        case .alchemy: "Alchemy"
        case .paupercommander: "Pauper Commander"
        case .duel: "Duel"
        case .oldschool: "Old School"
        case .premodern: "Premodern"
        case .predh: "PreDH"
        @unknown default: "Unknown"
        }
    }
}
