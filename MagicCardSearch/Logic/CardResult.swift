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
    
    // MARK: - Shared Properties (available on both card types)
    
    var id: String {
        field(regular: \.id, transforming: \.id)
    }
    
    var name: String {
        field(regular: \.name, transforming: \.name)
    }
    
    var legalities: [String: String]? {
        field(regular: \.legalities, transforming: \.legalities)
    }
    
    var gameChanger: Bool? {
        field(regular: \.gameChanger, transforming: \.gameChanger)
    }
    
    var allParts: [RelatedPart]? {
        field(regular: \.allParts, transforming: \.allParts)
    }
    
    var scryfallUri: String? {
        field(regular: \.scryfallUri, transforming: \.scryfallUri)
    }
    
    var setCode: String? {
        field(regular: \.setCode, transforming: \.setCode)
    }
    
    var setName: String? {
        field(regular: \.setName, transforming: \.setName)
    }
    
    var collectorNumber: String? {
        field(regular: \.collectorNumber, transforming: \.collectorNumber)
    }
    
    var rarity: String? {
        field(regular: \.rarity, transforming: \.rarity)
    }
    
    var lang: String? {
        field(regular: \.lang, transforming: \.lang)
    }
    
    var releasedAt: String? {
        field(regular: \.releasedAt, transforming: \.releasedAt)
    }
    
    var rulingsUri: String? {
        field(regular: \.rulingsUri, transforming: \.rulingsUri)
    }
    
    // MARK: - Front Face Properties (for transforming cards, returns front face data)
    
    var smallImageUrl: String? {
        field(regular: \.smallImageUrl, transforming: \.frontFace.smallImageUrl)
    }
    
    var normalImageUrl: String? {
        field(regular: \.normalImageUrl, transforming: \.frontFace.normalImageUrl)
    }
    
    var largeImageUrl: String? {
        field(regular: \.largeImageUrl, transforming: \.frontFace.largeImageUrl)
    }
    
    var manaCost: String? {
        field(regular: \.manaCost, transforming: \.frontFace.manaCost)
    }
    
    var typeLine: String? {
        field(regular: \.typeLine, transforming: \.frontFace.typeLine)
    }
    
    var oracleText: String? {
        field(regular: \.oracleText, transforming: \.frontFace.oracleText)
    }
    
    var flavorText: String? {
        field(regular: \.flavorText, transforming: \.frontFace.flavorText)
    }
    
    var power: String? {
        field(regular: \.power, transforming: \.frontFace.power)
    }
    
    var toughness: String? {
        field(regular: \.toughness, transforming: \.frontFace.toughness)
    }
    
    var artist: String? {
        field(regular: \.artist, transforming: \.frontFace.artist)
    }
    
    var colors: [String]? {
        field(regular: \.colors, transforming: \.frontFace.colors)
    }
    
    var colorIndicator: [String]? {
        field(regular: \.colorIndicator, transforming: \.frontFace.colorIndicator)
    }
    
    // MARK: - Helper Methods
    
    private func field<T>(regular regularPath: KeyPath<RegularCard, T>,
                          transforming transformingPath: KeyPath<TransformingCard, T>) -> T {
        switch self {
        case .regular(let card):
            return card[keyPath: regularPath]
        case .transforming(let card):
            return card[keyPath: transformingPath]
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
           layout == "transform" || layout == "modal_dfc" || layout == "reversible_card",
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
    let scryfallUri: String?
    let setCode: String?
    let setName: String?
    let collectorNumber: String?
    let rarity: String?
    let lang: String?
    let releasedAt: String?
    let rulingsUri: String?
    
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
        case scryfallUri = "scryfall_uri"
        case setCode = "set"
        case setName = "set_name"
        case collectorNumber = "collector_number"
        case rarity
        case lang
        case releasedAt = "released_at"
        case rulingsUri = "rulings_uri"
    }
    
    enum ImageUriKeys: String, CodingKey {
        case normal
        case small
        case large
    }
    
    init(
        id: String,
        name: String,
        smallImageUrl: String? = nil,
        normalImageUrl: String? = nil,
        largeImageUrl: String? = nil,
        manaCost: String? = nil,
        typeLine: String? = nil,
        oracleText: String? = nil,
        flavorText: String? = nil,
        power: String? = nil,
        toughness: String? = nil,
        artist: String? = nil,
        colors: [String]? = nil,
        colorIndicator: [String]? = nil,
        legalities: [String: String]? = nil,
        gameChanger: Bool? = nil,
        allParts: [RelatedPart]? = nil,
        scryfallUri: String? = nil,
        setCode: String? = nil,
        setName: String? = nil,
        collectorNumber: String? = nil,
        rarity: String? = nil,
        lang: String? = nil,
        releasedAt: String? = nil,
        rulingsUri: String? = nil,
    ) {
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
        self.scryfallUri = scryfallUri
        self.setCode = setCode
        self.setName = setName
        self.collectorNumber = collectorNumber
        self.rarity = rarity
        self.lang = lang
        self.releasedAt = releasedAt
        self.rulingsUri = rulingsUri
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
        scryfallUri = try? container.decode(String.self, forKey: .scryfallUri)
        setCode = try? container.decode(String.self, forKey: .setCode)
        setName = try? container.decode(String.self, forKey: .setName)
        collectorNumber = try? container.decode(String.self, forKey: .collectorNumber)
        rarity = try? container.decode(String.self, forKey: .rarity)
        lang = try? container.decode(String.self, forKey: .lang)
        releasedAt = try? container.decode(String.self, forKey: .releasedAt)
        rulingsUri = try? container.decode(String.self, forKey: .rulingsUri)
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
    let scryfallUri: String?
    let setCode: String?
    let setName: String?
    let collectorNumber: String?
    let rarity: String?
    let lang: String?
    let releasedAt: String?
    let rulingsUri: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case layout
        case cardFaces = "card_faces"
        case legalities
        case gameChanger = "game_changer"
        case allParts = "all_parts"
        case scryfallUri = "scryfall_uri"
        case setCode = "set"
        case setName = "set_name"
        case collectorNumber = "collector_number"
        case rarity
        case lang
        case releasedAt = "released_at"
        case rulingsUri = "rulings_uri"
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
        scryfallUri = try? container.decode(String.self, forKey: .scryfallUri)
        setCode = try? container.decode(String.self, forKey: .setCode)
        setName = try? container.decode(String.self, forKey: .setName)
        collectorNumber = try? container.decode(String.self, forKey: .collectorNumber)
        rarity = try? container.decode(String.self, forKey: .rarity)
        lang = try? container.decode(String.self, forKey: .lang)
        releasedAt = try? container.decode(String.self, forKey: .releasedAt)
        rulingsUri = try? container.decode(String.self, forKey: .rulingsUri)
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

// MARK: - Ruling

struct Ruling: Identifiable, Codable {
    let source: String
    let publishedAt: Date
    let comment: String
    
    var id: String { publishedAt.ISO8601Format() + comment }
    
    enum CodingKeys: String, CodingKey {
        case source
        case publishedAt = "published_at"
        case comment
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decode(String.self, forKey: .source)
        comment = try container.decode(String.self, forKey: .comment)
        
        let dateString = try container.decode(String.self, forKey: .publishedAt)
        // Parse ISO 8601 date format (yyyy-MM-dd)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        
        if let date = formatter.date(from: dateString) {
            publishedAt = date
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .publishedAt,
                in: container,
                debugDescription: "Date string does not match expected format"
            )
        }
    }
}

// MARK: - Scryfall Rulings Response

struct ScryfallRulingsResponse: Codable {
    let data: [Ruling]
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
