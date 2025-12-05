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
        case imageUrl = "image_url"
    }
}

// MARK: - API Response

struct CardSearchResponse: Codable {
    let cards: [CardResult]
    let total: Int
}
