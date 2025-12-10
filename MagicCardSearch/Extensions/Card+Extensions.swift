//
//  Card+Extensions.swift
//  MagicCardSearch
//
//  Extensions to make ScryfallKit's Card easier to work with in views
//

import Foundation
import ScryfallKit

extension Card {
    /// Returns both faces if this is a double-faced card, otherwise, nil.
    var bothFaces: (front: Card.Face, back: Card.Face)? {
        guard let faces = cardFaces, faces.count >= 2 else { return nil }
        
        return (faces[0], faces[1])
    }
    
    var isDoubleFaced: Bool {
        bothFaces != nil
    }
    
    var smallImageUrl: String? {
        field(\.imageUris?.small, \.imageUris?.small)
    }
    
    var normalImageUrl: String? {
        field(\.imageUris?.normal, \.imageUris?.normal)
    }
    
    var largeImageUrl: String? {
        field(\.imageUris?.large, \.imageUris?.large)
    }
    
    var typeLine: String? {
        field(\.typeLine, \.typeLine)
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
