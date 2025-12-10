//
//  CardListItem.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-09.
//

import Foundation

/// A lightweight representation of a card for storage in the user's card list
struct CardListItem: Identifiable, Codable, Equatable, Comparable {
    let id: String // Scryfall ID
    let name: String
    let typeLine: String?
    let smallImageUrl: String?
    let setCode: String?
    let releasedAt: String? // ISO 8601 date string
    
    init(id: String, name: String, typeLine: String?, smallImageUrl: String?, setCode: String? = nil, releasedAt: String? = nil) {
        self.id = id
        self.name = name
        self.typeLine = typeLine
        self.smallImageUrl = smallImageUrl
        self.setCode = setCode
        self.releasedAt = releasedAt
    }
    
    /// Create a CardListItem from a CardResult
    init(from card: CardResult) {
        self.id = card.id
        self.name = card.name
        self.typeLine = card.typeLine
        self.smallImageUrl = card.smallImageUrl
        self.setCode = card.setCode
        self.releasedAt = card.releasedAt
    }
    
    // MARK: - Comparable
    
    static func < (lhs: CardListItem, rhs: CardListItem) -> Bool {
        // First sort by name
        if lhs.name != rhs.name {
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        
        // If names match, sort by release date (newer first)
        if let lhsDate = lhs.releasedAt, let rhsDate = rhs.releasedAt {
            return lhsDate > rhsDate
        }
        
        // If one has a date and the other doesn't, prefer the one with a date
        if lhs.releasedAt != nil {
            return true
        }
        if rhs.releasedAt != nil {
            return false
        }
        
        // Fallback to ID comparison for stability
        return lhs.id < rhs.id
    }
}
