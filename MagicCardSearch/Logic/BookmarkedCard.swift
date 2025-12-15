//
//  CardListItem.swift
//  MagicCardSearch
//
//  A serializable wrapper for persisting card information to disk.
//  Does not persist the full ScryfallKit Card object.
//

import Foundation
import ScryfallKit

struct BookmarkedCard: Identifiable, Codable, Equatable, Hashable, Comparable {
    let id: UUID
    let name: String
    let typeLine: String?
    let smallImageUrl: String?
    let setCode: String
    let setName: String
    let collectorNumber: String
    let releasedAt: String
    let addedToListAt: Date
    
    init(from card: Card) {
        self.id = card.id
        self.name = card.name
        self.typeLine = card.typeLine
        self.setCode = card.set
        self.setName = card.setName
        self.collectorNumber = card.collectorNumber
        self.releasedAt = card.releasedAt
        self.smallImageUrl = card.primaryImageUris?.small
        self.addedToListAt = Date()
    }
    
    // MARK: - Comparable
    
    static func < (lhs: BookmarkedCard, rhs: BookmarkedCard) -> Bool {
        if lhs.name != rhs.name {
            return lhs.name < rhs.name
        }
        
        if lhs.releasedAt == rhs.releasedAt {
            return lhs.id < rhs.id
        }
        
        return lhs.releasedAt > rhs.releasedAt
    }
}
