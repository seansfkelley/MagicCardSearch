//
//  CardResult.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import Foundation

enum CardResult: Identifiable, Codable {
    case regular(RegularCard)
    case transforming(TransformingCard)
    
    var id: String {
        switch self {
        case .regular(let card):
            return card.id
        case .transforming(let card):
            return card.id
        }
    }
    
    var name: String {
        switch self {
        case .regular(let card):
            return card.name
        case .transforming(let card):
            return card.name
        }
    }
    
    // Convenience accessors for regular cards
    var smallImageUrl: String? {
        switch self {
        case .regular(let card):
            return card.smallImageUrl
        case .transforming(let card):
            return card.frontFace.smallImageUrl
        }
    }
    
    var normalImageUrl: String? {
        switch self {
        case .regular(let card):
            return card.normalImageUrl
        case .transforming(let card):
            return card.frontFace.normalImageUrl
        }
    }
    
    var largeImageUrl: String? {
        switch self {
        case .regular(let card):
            return card.largeImageUrl
        case .transforming(let card):
            return card.frontFace.largeImageUrl
        }
    }
    
    var manaCost: String? {
        switch self {
        case .regular(let card):
            return card.manaCost
        case .transforming(let card):
            return card.frontFace.manaCost
        }
    }
    
    var typeLine: String? {
        switch self {
        case .regular(let card):
            return card.typeLine
        case .transforming(let card):
            return card.frontFace.typeLine
        }
    }
    
    var oracleText: String? {
        switch self {
        case .regular(let card):
            return card.oracleText
        case .transforming(let card):
            return card.frontFace.oracleText
        }
    }
    
    var flavorText: String? {
        switch self {
        case .regular(let card):
            return card.flavorText
        case .transforming(let card):
            return card.frontFace.flavorText
        }
    }
    
    var power: String? {
        switch self {
        case .regular(let card):
            return card.power
        case .transforming(let card):
            return card.frontFace.power
        }
    }
    
    var toughness: String? {
        switch self {
        case .regular(let card):
            return card.toughness
        case .transforming(let card):
            return card.frontFace.toughness
        }
    }
    
    var artist: String? {
        switch self {
        case .regular(let card):
            return card.artist
        case .transforming(let card):
            return card.frontFace.artist
        }
    }
    
    var colors: [String]? {
        switch self {
        case .regular(let card):
            return card.colors
        case .transforming(let card):
            return card.frontFace.colors
        }
    }
    
    var colorIndicator: [String]? {
        switch self {
        case .regular(let card):
            return card.colorIndicator
        case .transforming(let card):
            return card.frontFace.colorIndicator
        }
    }
    
    var legalities: [String: String]? {
        switch self {
        case .regular(let card):
            return card.legalities
        case .transforming(let card):
            return card.legalities
        }
    }
    
    var gameChanger: Bool? {
        switch self {
        case .regular(let card):
            return card.gameChanger
        case .transforming(let card):
            return card.gameChanger
        }
    }
    
    var allParts: [RelatedPart]? {
        switch self {
        case .regular(let card):
            return card.allParts
        case .transforming(let card):
            return card.allParts
        }
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case layout
        case cardFaces = "card_faces"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let layout = try? container.decode(String.self, forKey: .layout)
        
        // Check if this is a double-faced card
        if let layout = layout,
           (layout == "transform" || layout == "modal_dfc" || layout == "reversible_card"),
           let cardFaces = try? container.decode([CardFace].self, forKey: .cardFaces),
           cardFaces.count >= 2 {
            self = .transforming(try TransformingCard(from: decoder))
        } else {
            self = .regular(try RegularCard(from: decoder))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .regular(let card):
            try card.encode(to: encoder)
        case .transforming(let card):
            try card.encode(to: encoder)
        }
    }
}

// MARK: - Regular Card

struct RegularCard: Identifiable, Codable {
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

// MARK: - Transforming Card

struct TransformingCard: Identifiable, Codable {
    let id: String
    let name: String
    let layout: String
    let frontFace: CardFace
    let backFace: CardFace
    let legalities: [String: String]?
    let gameChanger: Bool?
    let allParts: [RelatedPart]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case layout
        case cardFaces = "card_faces"
        case legalities
        case gameChanger = "game_changer"
        case allParts = "all_parts"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        layout = try container.decodeIfPresent(String.self, forKey: .layout) ?? "transform"
        
        let faces = try container.decode([CardFace].self, forKey: .cardFaces)
        guard faces.count >= 2 else {
            throw DecodingError.dataCorruptedError(
                forKey: .cardFaces,
                in: container,
                debugDescription: "Expected at least 2 card faces"
            )
        }
        
        frontFace = faces[0]
        backFace = faces[1]
        legalities = try? container.decode([String: String].self, forKey: .legalities)
        gameChanger = try? container.decode(Bool.self, forKey: .gameChanger)
        allParts = try? container.decode([RelatedPart].self, forKey: .allParts)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(layout, forKey: .layout)
        try container.encode([frontFace, backFace], forKey: .cardFaces)
    }
}

// MARK: - Card Face

struct CardFace: Codable {
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
    
    enum CodingKeys: String, CodingKey {
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
    }
    
    enum ImageUriKeys: String, CodingKey {
        case normal
        case small
        case large
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
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
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
    }
}

// MARK: - Related Part

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

// MARK: - Scryfall API Response

struct ScryfallSearchResponse: Codable {
    let data: [CardResult]
    let totalCards: Int?
    let hasMore: Bool
    let nextPage: String?
    let warnings: [String]?
    
    enum CodingKeys: String, CodingKey {
        case data
        case totalCards = "total_cards"
        case hasMore = "has_more"
        case nextPage = "next_page"
        case warnings
    }
}
