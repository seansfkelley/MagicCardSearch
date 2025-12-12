//
//  Card.Layout+isDoubleFaced.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-12.
//
import ScryfallKit

extension Card.Layout {
    var isDoubleFaced: Bool {
        switch self {
        case .transform, .meld, .modalDfc, .doubleSided, .reversibleCard, .doubleFacedToken: true
        default: false
        }
    }
}
