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
        // A bit silly, but makes it trivial to support future formats.
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
        @unknown default: "Unknown"
        }
    }
}
