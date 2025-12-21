//
//  SearchHistoryTracker.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-18.
//
import Foundation
import Observation

struct FilterEntry: Codable {
    let filter: SearchFilter
    let lastUsedDate: Date
}

struct CompleteSearchEntry: Codable {
    let filters: [SearchFilter]
    let lastUsedDate: Date
}

struct HistoryData: Codable {
    var filterEntries: [SearchFilter: FilterEntry]
    var completeSearchEntries: [CompleteSearchEntry]
    
    init(filterEntries: [SearchFilter: FilterEntry] = [:], completeSearchEntries: [CompleteSearchEntry] = []) {
        self.filterEntries = filterEntries
        self.completeSearchEntries = completeSearchEntries
    }
}

@Observable
class SearchHistoryTracker {
    // MARK: - Properties

    private(set) var filterEntries: [SearchFilter: FilterEntry] = [:]
    private(set) var completeSearchEntries: [CompleteSearchEntry] = []

    private let hardLimit: Int
    private let softLimit: Int
    private let maxAgeInDays: Int
    // TODO: Is this really the right way to do persistence? Should I dependecy-inject it?
    private let persistenceKey: String
    
    private var sortedCache: [FilterEntry]?
    
    var sortedFilterHistory: [FilterEntry] {
        if let cached = sortedCache {
            return cached
        }

        let sorted = filterEntries.values.sorted(using: [
            KeyPathComparator(\.lastUsedDate, order: .reverse),
            KeyPathComparator(\.filter.description, comparator: .localizedStandard),
        ])

        sortedCache = sorted
        return sorted
    }

    // MARK: - Initialization

    init(hardLimit: Int = 1000, softLimit: Int = 500, maxAgeInDays: Int = 90, persistenceKey: String = "filterHistory") {
        self.hardLimit = hardLimit
        self.softLimit = softLimit
        self.maxAgeInDays = maxAgeInDays
        self.persistenceKey = persistenceKey
        
        loadHistory()
    }

    // MARK: - Public Methods

    func recordUsage(of filter: SearchFilter) {
        let entry = FilterEntry(
            filter: filter,
            lastUsedDate: Date(),
        )
        filterEntries[filter] = entry
        invalidateCache()
        saveHistory()
    }
    
    func recordUsage(of filters: [SearchFilter]) {
        if let existingIndex = completeSearchEntries.firstIndex(where: { $0.filters == filters }) {
            completeSearchEntries.remove(at: existingIndex)
        }
        
        let entry = CompleteSearchEntry(
            filters: filters,
            lastUsedDate: Date()
        )
        completeSearchEntries.insert(entry, at: 0)
        saveHistory()
    }

    func delete(filter: SearchFilter) {
        filterEntries.removeValue(forKey: filter)
        invalidateCache()
        saveHistory()
    }
    
    func delete(filters: [SearchFilter]) {
        if let index = completeSearchEntries.firstIndex(where: { $0.filters == filters }) {
            completeSearchEntries.remove(at: index)
            saveHistory()
        }
    }

    // TODO: Can this be auto-run on the set of filterEntries?
    private func invalidateCache() {
        sortedCache = nil
    }
    
    // MARK: - Garbage Collection
    
    private func truncateByAgeAndSize<T>(_ entries: [T], getDate: (T) -> Date) -> [T] {
        guard !entries.isEmpty else {
            return entries
        }
        
        var truncated = entries
        
        let cutoff = Date.now.addingTimeInterval(TimeInterval(-maxAgeInDays * 24 * 60 * 60))
        if let i = truncated.firstIndex(where: { getDate($0) < cutoff }) {
            truncated = Array(truncated[..<i])
        }
        
        if truncated.count > hardLimit {
            truncated = Array(truncated[..<softLimit])
        }
        
        return truncated
    }

    func maybeGarbageCollectHistory() {
        var didModify = false

        if !sortedFilterHistory.isEmpty {
            let originalCount = sortedFilterHistory.count
            let reducedHistory = truncateByAgeAndSize(sortedFilterHistory) { $0.lastUsedDate }
            
            if reducedHistory.count != originalCount {
                filterEntries = reducedHistory.reduce(into: [:]) { dict, entry in
                    dict[entry.filter] = entry
                }
                invalidateCache()
                didModify = true
                
                print("Garbage collected \(originalCount - reducedHistory.count) filter entries")
            }
        }
        
        if !completeSearchEntries.isEmpty {
            let originalCount = completeSearchEntries.count
            let reducedSearches = truncateByAgeAndSize(completeSearchEntries) { $0.lastUsedDate }
            
            if reducedSearches.count != originalCount {
                completeSearchEntries = reducedSearches
                didModify = true
                
                print("Garbage collected \(originalCount - reducedSearches.count) complete search entries")
            }
        }
        
        if didModify {
            saveHistory()
        }
    }

    // MARK: - Persistence

    private func saveHistory() {
        do {
            let historyData = HistoryData(
                filterEntries: filterEntries,
                completeSearchEntries: completeSearchEntries
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(historyData)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            print("Failed to save filter history: \(error)")
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else {
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let historyData = try decoder.decode(HistoryData.self, from: data)
            filterEntries = historyData.filterEntries
            completeSearchEntries = historyData.completeSearchEntries
        } catch {
            print("Failed to load filter history: \(error)")
            filterEntries = [:]
            completeSearchEntries = []
        }
    }
}
