//
//  Card+Extensions.swift
//  MagicCardSearch
//
//  Extensions to make ScryfallKit's Card easier to work with in views
//

import Foundation
import ScryfallKit

extension Card {
    /// Returns the front face for double-faced cards, or nil for single-faced cards
    var frontFace: Card.Face? {
        return cardFaces?.first
    }
    
    /// Returns the back face for double-faced cards, or nil for single-faced cards
    var backFace: Card.Face? {
        guard let faces = cardFaces, faces.count >= 2 else { return nil }
        return faces[1]
    }
    
    /// True if this is a double-faced card (has multiple faces)
    var isDoubleFaced: Bool {
        return (cardFaces?.count ?? 0) >= 2
    }
    
    /// Get the small image URL, preferring card_faces for double-faced cards
    var smallImageURL: String? {
        if let faces = cardFaces, let firstFace = faces.first {
            return firstFace.imageUris?.small
        }
        return imageUris?.small
    }
    
    /// Get the normal image URL, preferring card_faces for double-faced cards
    var normalImageURL: String? {
        if let faces = cardFaces, let firstFace = faces.first {
            return firstFace.imageUris?.normal
        }
        return imageUris?.normal
    }
    
    /// Get the large image URL, preferring card_faces for double-faced cards
    var largeImageURL: String? {
        if let faces = cardFaces, let firstFace = faces.first {
            return firstFace.imageUris?.large
        }
        return imageUris?.large
    }
    
    /// Get the mana cost, preferring front face for double-faced cards
    var displayManaCost: String? {
        if let faces = cardFaces, let firstFace = faces.first {
            return firstFace.manaCost
        }
        return manaCost
    }
    
    /// Get the type line, preferring front face for double-faced cards
    var displayTypeLine: String? {
        if let faces = cardFaces, let firstFace = faces.first {
            return firstFace.typeLine
        }
        return typeLine
    }
    
    /// Get the oracle text, preferring front face for double-faced cards
    var displayOracleText: String? {
        if let faces = cardFaces, let firstFace = faces.first {
            return firstFace.oracleText
        }
        return oracleText
    }
    
    /// Get the flavor text, preferring front face for double-faced cards
    var displayFlavorText: String? {
        if let faces = cardFaces, let firstFace = faces.first {
            return firstFace.flavorText
        }
        return flavorText
    }
    
    /// Get the power, preferring front face for double-faced cards
    var displayPower: String? {
        if let faces = cardFaces, let firstFace = faces.first {
            return firstFace.power
        }
        return power
    }
    
    /// Get the toughness, preferring front face for double-faced cards
    var displayToughness: String? {
        if let faces = cardFaces, let firstFace = faces.first {
            return firstFace.toughness
        }
        return toughness
    }
    
    /// Get the artist, preferring front face for double-faced cards
    var displayArtist: String? {
        if let faces = cardFaces, let firstFace = faces.first {
            return firstFace.artist
        }
        return artist
    }
    
    /// Get the colors, preferring front face for double-faced cards (as strings)
    var displayColors: [String]? {
        if let faces = cardFaces, let firstFace = faces.first {
            return firstFace.colors?.map { $0.rawValue }
        }
        return colors?.map { $0.rawValue }
    }
    
    /// Get the color indicator, preferring front face for double-faced cards (as strings)
    var displayColorIndicator: [String]? {
        if let faces = cardFaces, let firstFace = faces.first {
            return firstFace.colorIndicator?.map { $0.rawValue }
        }
        return colorIndicator?.map { $0.rawValue }
    }
}

extension Card.Face {
    /// Convenience to check if this face has power/toughness
    var hasPowerToughness: Bool {
        return power != nil && toughness != nil
    }
    
    /// Get colors as string array
    var colorsAsStrings: [String]? {
        return colors?.map { $0.rawValue }
    }
    
    /// Get color indicator as string array
    var colorIndicatorAsStrings: [String]? {
        return colorIndicator?.map { $0.rawValue }
    }
}
