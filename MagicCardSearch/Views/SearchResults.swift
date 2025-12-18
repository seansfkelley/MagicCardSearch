//
//  SearchResults.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-18.
//

import ScryfallKit

struct SearchResults {
    let totalCount: Int
    let cards: [Card]
    let warnings: [String]
    let nextPageUrl: String?
}
