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
    let smallImageUrl: String?
    let normalImageUrl: String?
    let largeImageUrl: String?
    let manaCost: String?
    let typeLine: String?
    let oracleText: String?
    let flavorText: String?
    let power: String?
    let toughness: String?
    let artist: String?
    let colors: [String]?
    let colorIndicator: [String]?
    let legalities: [String: String]?
    let gameChanger: Bool?
    let allParts: [RelatedPart]?
    
    struct RelatedPart: Identifiable, Codable {
        let id: String
        let name: String
        let typeLine: String?
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case typeLine = "type_line"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case imageUris = "image_uris"
        case manaCost = "mana_cost"
        case typeLine = "type_line"
        case oracleText = "oracle_text"
        case flavorText = "flavor_text"
        case power
        case toughness
        case artist
        case colors
        case colorIndicator = "color_indicator"
        case legalities
        case gameChanger = "game_changer"
        case allParts = "all_parts"
    }
    
    enum ImageUriKeys: String, CodingKey {
        case normal
        case small
        case large
    }
    
    init(id: String, name: String, smallImageUrl: String? = nil, normalImageUrl: String? = nil, 
         largeImageUrl: String? = nil, manaCost: String? = nil, 
         typeLine: String? = nil, oracleText: String? = nil, flavorText: String? = nil,
         power: String? = nil, toughness: String? = nil, artist: String? = nil,
         colors: [String]? = nil, colorIndicator: [String]? = nil, legalities: [String: String]? = nil,
         gameChanger: Bool? = nil, allParts: [RelatedPart]? = nil) {
        self.id = id
        self.name = name
        self.smallImageUrl = smallImageUrl
        self.normalImageUrl = normalImageUrl
        self.largeImageUrl = largeImageUrl
        self.manaCost = manaCost
        self.typeLine = typeLine
        self.oracleText = oracleText
        self.flavorText = flavorText
        self.power = power
        self.toughness = toughness
        self.artist = artist
        self.colors = colors
        self.colorIndicator = colorIndicator
        self.legalities = legalities
        self.gameChanger = gameChanger
        self.allParts = allParts
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        // Try to extract image URLs from image_uris
        if let imageUrisContainer = try? container.nestedContainer(keyedBy: ImageUriKeys.self, forKey: .imageUris) {
            smallImageUrl = try? imageUrisContainer.decode(String.self, forKey: .small)
            normalImageUrl = try? imageUrisContainer.decode(String.self, forKey: .normal)
            largeImageUrl = try? imageUrisContainer.decode(String.self, forKey: .large)
        } else {
            smallImageUrl = nil
            normalImageUrl = nil
            largeImageUrl = nil
        }
        
        manaCost = try? container.decode(String.self, forKey: .manaCost)
        typeLine = try? container.decode(String.self, forKey: .typeLine)
        oracleText = try? container.decode(String.self, forKey: .oracleText)
        flavorText = try? container.decode(String.self, forKey: .flavorText)
        power = try? container.decode(String.self, forKey: .power)
        toughness = try? container.decode(String.self, forKey: .toughness)
        artist = try? container.decode(String.self, forKey: .artist)
        colors = try? container.decode([String].self, forKey: .colors)
        colorIndicator = try? container.decode([String].self, forKey: .colorIndicator)
        legalities = try? container.decode([String: String].self, forKey: .legalities)
        gameChanger = try? container.decode(Bool.self, forKey: .gameChanger)
        allParts = try? container.decode([RelatedPart].self, forKey: .allParts)
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
