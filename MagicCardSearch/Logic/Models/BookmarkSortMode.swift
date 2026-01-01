//
//  BookmarkedCardStore.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-31.
//
import Foundation

enum BookmarkSortMode: String, CaseIterable, Identifiable {
    case name
    case dateAddedNewest
    case dateAddedOldest
    case releaseDateNewest
    case releaseDateOldest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .name:
            return "Name"
        case .releaseDateNewest, .releaseDateOldest:
            return "Release Date"
        case .dateAddedNewest, .dateAddedOldest:
            return "Date Added"
        }
    }

    var subtitle: String? {
        switch self {
        case .name:
            return nil
        case .releaseDateNewest, .dateAddedNewest:
            return "Newest First"
        case .releaseDateOldest, .dateAddedOldest:
            return "Oldest First"
        }
    }
}
