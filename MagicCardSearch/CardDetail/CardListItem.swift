//
//  CardListItem.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-09.
//

import Foundation

/// A lightweight representation of a card for storage in the user's card list
struct CardListItem: Identifiable, Codable, Equatable {
    let id: String // Scryfall ID
    let name: String
    let typeLine: String?
    let smallImageUrl: String?
    
    init(id: String, name: String, typeLine: String?, smallImageUrl: String?) {
        self.id = id
        self.name = name
        self.typeLine = typeLine
        self.smallImageUrl = smallImageUrl
    }
    
    /// Create a CardListItem from a CardResult
    init(from card: CardResult) {
        self.id = card.id
        self.name = card.name
        self.typeLine = card.typeLine
        self.smallImageUrl = card.smallImageUrl
    }
}
