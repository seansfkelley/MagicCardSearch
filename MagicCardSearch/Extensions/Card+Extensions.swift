//
//  Card+Extensions.swift
//  MagicCardSearch
//
//  Extensions to make ScryfallKit's Card easier to work with in views
//

import Foundation
import ScryfallKit

extension Card {
    var releasedAtAsDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: releasedAt)
    }
    
    /// Returns both faces if this is a double-faced card, otherwise, nil.
    var bothFaces: (front: Card.Face, back: Card.Face)? {
        guard let faces = cardFaces, faces.count >= 2 else { return nil }
        
        return (faces[0], faces[1])
    }
    
    var isDoubleFaced: Bool {
        bothFaces != nil
    }
    
    var primaryImageUris: Card.ImageUris? {
        field(\.imageUris, \.imageUris)
    }
    
    private func field<T>(_ normalPath: KeyPath<Card, T>,
                          _ doubleFacedPath: KeyPath<Card.Face, T>) -> T {
        return if let (front, _) = bothFaces {
            front[keyPath: doubleFacedPath]
        } else {
            self[keyPath: normalPath]
        }
    }
}
