//
//  CardResult.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import Foundation

struct CardResult: Identifiable, Codable {
    let id: String
    let name: String
    let imageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case imageUris = "image_uris"
    }
    
    enum ImageUriKeys: String, CodingKey {
        case normal
        case small
        case large
    }
    
    init(id: String, name: String, imageUrl: String?) {
        self.id = id
        self.name = name
        self.imageUrl = imageUrl
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        // Try to extract image URL from image_uris
        if let imageUrisContainer = try? container.nestedContainer(keyedBy: ImageUriKeys.self, forKey: .imageUris) {
            imageUrl = try? imageUrisContainer.decode(String.self, forKey: .normal)
        } else {
            imageUrl = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
    }
}

// MARK: - Scryfall API Response

struct ScryfallSearchResponse: Codable {
    let data: [CardResult]
    let totalCards: Int?
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case data
        case totalCards = "total_cards"
        case hasMore = "has_more"
    }
}
