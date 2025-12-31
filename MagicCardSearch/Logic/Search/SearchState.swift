//
//  SearchState.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-31.
//
import Logging

private let logger = Logger(label: "SearchState")

class SearchState {
    private let filterHistory: FilterHistoryStore
    private let searchHistory: SearchHistoryStore

    private(set) var searchError: Error?

    init(filterHistory: FilterHistoryStore, searchHistory: SearchHistoryStore) {
        self.filterHistory = filterHistory
        self.searchHistory = searchHistory
    }

    public func delete(filter: SearchFilter) {
        do {
            try filterHistory.deleteUsage(of: filter)
        } catch {
            logger.error("error while deleting filter", metadata: [
                "error": "\(error)",
            ])
            searchError = error
        }
    }

    public func unpin(filter: SearchFilter) {
        do {
            // Keep it around near the top since you just modified it.
            try filterHistory.recordUsage(of: filter)
        } catch {
            logger.error("error while unpinning filter", metadata: [
                "error": "\(error)",
            ])
            searchError = error
        }
    }
}
