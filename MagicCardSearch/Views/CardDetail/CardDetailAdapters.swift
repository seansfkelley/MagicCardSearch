//
//  CardDetailAdapters.swift
//  MagicCardSearch
//
//  Adapter types to bridge between ScryfallKit models and existing view code
//

import Foundation

/// Adapter to make ScryfallKit's Card.RelatedCard work with existing RelatedPart views
struct RelatedPartAdapter: Identifiable {
    let id: String
    let name: String
    let typeLine: String?
    
    init(from relatedCard: Card.RelatedCard) {
        self.id = relatedCard.id
        self.name = relatedCard.name
        self.typeLine = relatedCard.typeLine
    }
}

/// Adapter to make ScryfallKit's Card.Ruling work with existing Ruling views
struct RulingAdapter: Identifiable {
    let source: String
    let publishedAt: Date
    let comment: String
    
    var id: String { publishedAt.ISO8601Format() + comment }
    
    init(from ruling: Card.Ruling) {
        self.source = ruling.source.rawValue
        self.publishedAt = ruling.publishedAt
        self.comment = ruling.comment
    }
}
