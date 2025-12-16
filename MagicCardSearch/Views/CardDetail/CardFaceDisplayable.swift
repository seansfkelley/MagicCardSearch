//
//  CardFaceDisplayable.swift
//  MagicCardSearch
//
//  Protocol for unified card face rendering
//

import Foundation
import ScryfallKit

/// Protocol for types that can be displayed as a card face
protocol CardFaceDisplayable {
    var name: String { get }
    var typeLine: String? { get }
    var oracleText: String? { get }
    var flavorText: String? { get }
    var colorIndicator: [Card.Color]? { get }
    var power: String? { get }
    var toughness: String? { get }
    var loyalty: String? { get }
    var defense: String? { get }
    var artist: String? { get }
    var imageUris: Card.ImageUris? { get }
    
    // Properties that have differing types in ScryfallKit so need another name.
    var displayableManaCost: String { get }
}

// MARK: - Card.Face Conformance

extension Card.Face: CardFaceDisplayable {
    var displayableManaCost: String {
        return manaCost
    }
}

// MARK: - Card Conformance

extension Card: CardFaceDisplayable {
    var displayableManaCost: String {
        return manaCost ?? ""
    }
}

// MARK: - Image Quality

enum CardImageQuality {
    case small
    case normal
    case large
    
    func uri(from: Card.ImageUris?) -> String? {
        switch self {
        case .small: from?.small
        case .normal: from?.normal
        case .large: from?.large
        }
    }
    
    static func bestQualityUri(from uris: Card.ImageUris?) -> String? {
        uris?.large ?? uris?.normal ?? uris?.small
    }
}
