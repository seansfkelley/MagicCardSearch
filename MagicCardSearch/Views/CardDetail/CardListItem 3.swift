//
//  CardListItem.swift
//  MagicCardSearch
//
//  A serializable wrapper for persisting card information to disk.
//  Does not persist the full ScryfallKit Card object.
//

import Foundation
import ScryfallKit

/// A lightweight, serializable representation of a card for the favorites list
struct CardListItem: Identifiable, Codable, Equatable, Hashable, Comparable {
    let id: String
    let name: String
    let typeLine: String?
    let smallImageUrl: String?
    let setCode: String?
    let releasedAt: String?
    
    /// Initialize from a ScryfallKit Card
    init(from card: Card) {
        self.id = card.id
        self.name = card.name
        self.typeLine = card.typeLine
        self.setCode = card.set
        self.releasedAt = card.releasedAt
        
        // For double-faced cards, prefer the front face image
        if let cardFaces = card.cardFaces, let firstFace = cardFaces.first {
            self.smallImageUrl = firstFace.imageUris?.small
        } else {
            self.smallImageUrl = card.imageUris?.small
        }
    }
    
    // MARK: - Comparable
    
    /// Sort by name, then by release date
    static func < (lhs: CardListItem, rhs: CardListItem) -> Bool {
        if lhs.name != rhs.name {
            return lhs.name < rhs.name
        }
        
        // If names are equal, sort by release date (most recent first)
        guard let lhsDate = lhs.releasedAt, let rhsDate = rhs.releasedAt else {
            return lhs.id < rhs.id // Fallback to ID if no dates
        }
        
        return lhsDate > rhsDate
    }
}
