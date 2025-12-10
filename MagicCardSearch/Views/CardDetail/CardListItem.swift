//
//  CardListItem.swift
//  MagicCardSearch
//
//  A serializable wrapper for persisting card information to disk.
//  Does not persist the full ScryfallKit Card object.
//

import Foundation
import ScryfallKit

struct CardListItem: Identifiable, Codable, Equatable, Hashable, Comparable {
    let id: UUID
    let name: String
    let typeLine: String?
    let smallImageUrl: String?
    let setCode: String?
    let releasedAt: String?
    
    init(from card: Card) {
        self.id = card.id
        self.name = card.name
        self.typeLine = card.typeLine
        self.setCode = card.set
        self.releasedAt = card.releasedAt
        self.smallImageUrl = card.primaryImageUris?.small
    }
    
    // MARK: - Comparable
    
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
