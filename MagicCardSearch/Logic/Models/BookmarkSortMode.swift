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

    var sortDescriptors: [SortDescriptor<BookmarkedCard>] {
        switch self {
        case .name:
            [
                SortDescriptor(\.name),
                SortDescriptor(\.setCode),
                SortDescriptor(\.collectorNumber),
            ]
        case .releaseDateNewest:
            [
                SortDescriptor(\.releasedAt, order: .reverse),
                SortDescriptor(\.name),
                SortDescriptor(\.setCode),
                SortDescriptor(\.collectorNumber),
            ]
        case .releaseDateOldest:
            [
                SortDescriptor(\.releasedAt),
                SortDescriptor(\.name),
                SortDescriptor(\.setCode),
                SortDescriptor(\.collectorNumber),
            ]
        case .dateAddedNewest:
            [
                SortDescriptor(\.bookmarkedAt, order: .reverse),
                SortDescriptor(\.name),
                SortDescriptor(\.setCode),
                SortDescriptor(\.collectorNumber),
            ]
        case .dateAddedOldest:
            [
                SortDescriptor(\.bookmarkedAt),
                SortDescriptor(\.name),
                SortDescriptor(\.setCode),
                SortDescriptor(\.collectorNumber),
            ]
        }
    }
}
