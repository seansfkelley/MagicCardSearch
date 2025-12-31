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

    // MARK: - Filter-only Methods

    public func record(filter: SearchFilter) {
        perform("recording filter") {
            try filterHistory.recordUsage(of: filter)
        }
    }

    public func delete(filter: SearchFilter) {
        perform("deleting filter") {
            try filterHistory.deleteUsage(of: filter)
        }
    }

    public func pin(filter: SearchFilter) {
        // TODO
    }

    public func unpin(filter: SearchFilter) {
        perform("unpinning filter") {
            // Keep it around near the top since you just modified it.
            try filterHistory.recordUsage(of: filter)
        }
    }

    // MARK: - Search Methods

    public func record(search: [SearchFilter]) {
        perform("recording search") {
            try searchHistory.recordSearch(with: search)

            for filter in search {
                // TODO: Should this recursively add the sub-filters?
                try filterHistory.recordUsage(of: filter)
            }
        }
    }

    public func delete(search: [SearchFilter]) {
        perform("deleting search") {
            try searchHistory.deleteSearch(with: search)
        }
    }

    public func getLatestSearches(count: Int) -> [SearchHistoryStore.Row] {
        perform("retrieving latest searches", defaultValue: []) {
            try Array(searchHistory.allSearchesChronologically.prefix(count))
        }
    }

    // MARK: - Private Methods

    private func perform(_ operation: String, _ block: () throws -> Void) {
        do {
            try block()
        } catch {
            logger.error("error while \(operation)", metadata: [
                "error": "\(error)",
            ])
            lastError = error
        }
    }

    private func perform<T>(_ operation: String, defaultValue: T, _ block: () throws -> T) -> T {
        do {
            return try block()
        } catch {
            logger.error("error while \(operation)", metadata: [
                "error": "\(error)",
            ])
            lastError = error
            return defaultValue
        }
    }
}
