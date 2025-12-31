//
//  HistoryAndPinnedState.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-31.
//
import Logging

private let logger = Logger(label: "HistoryAndPinnedState")

// TODO: Remove this decorator once I have disentagled a bunch of the state management.
@MainActor
class HistoryAndPinnedState {
    private let filterHistory: FilterHistoryStore
    private let searchHistory: SearchHistoryStore

    private(set) var lastError: Error?

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
            lastError = error
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
            lastError = error
        }
    }

    public func getLatestSearches(count: Int) -> [SearchHistoryStore.Row] {
        do {
            // TODO: Does Swift get bitchy if this array isn't long enough?
            return try Array(searchHistory.allSearchesChronologically[...count])
        } catch {
            logger.error("error while retrieving latest searches", metadata: [
                "error": "\(error)",
            ])
            lastError = error
            return []
        }
    }
}
