//
//  ScryfallKitAdapters.swift
//  MagicCardSearch
//
//  Adapter types to bridge between ScryfallKit types and view expectations
//

import Foundation
import ScryfallKit

// MARK: - RelatedPart

/// A lightweight adapter that conforms to the old RelatedPart interface
/// but wraps ScryfallKit's RelatedCard type
struct RelatedPart: Identifiable {
    let id: String
    let name: String
    let typeLine: String?
}

/// Adapter to convert ScryfallKit's Card.RelatedCard to our RelatedPart
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

// Make RelatedPartAdapter conform to the same protocol as RelatedPart for view compatibility
extension RelatedPartAdapter {
    var asRelatedPart: RelatedPart {
        RelatedPart(id: id, name: name, typeLine: typeLine)
    }
}

// MARK: - Ruling

/// Adapter for ScryfallKit's Card.Ruling to match old interface expectations
struct RulingAdapter: Identifiable {
    let source: String
    let publishedAt: Date
    let comment: String
    
    var id: String { publishedAt.ISO8601Format() + comment }
    
    init(from ruling: Card.Ruling) {
        self.source = ruling.source
        self.comment = ruling.comment
        
        // Parse the publishedAt string to a Date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        
        if let date = formatter.date(from: ruling.publishedAt) {
            self.publishedAt = date
        } else {
            // Fallback to current date if parsing fails
            self.publishedAt = Date()
        }
    }
}
