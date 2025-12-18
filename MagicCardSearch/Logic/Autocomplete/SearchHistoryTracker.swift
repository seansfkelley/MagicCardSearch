//
//  SearchHistoryTracker.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-18.
//
import Foundation
import Observation

struct HistoryEntry: Codable {
    let filter: SearchFilter
    let lastUsedDate: Date
    let isPinned: Bool // Only used for garbage collection logic
}

@Observable
class SearchHistoryTracker {
    // MARK: - Properties

    private(set) var historyByFilter: [SearchFilter: HistoryEntry] = [:]

    private let hardLimit: Int
    private let softLimit: Int
    private let maxAgeInDays: Int
    // TODO: Is this really the right way to do persistence? Should I dependecy-inject it?
    private let persistenceKey: String

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
        let entry = HistoryEntry(
            filter: filter,
            lastUsedDate: Date(),
            isPinned: false // History doesn't track pinning anymore
        )
        historyByFilter[filter] = entry
        saveHistory()
    }

    func delete(filter: SearchFilter) {
        historyByFilter.removeValue(forKey: filter)
        saveHistory()
    }

    // MARK: - Garbage Collection

    func maybeGarbageCollectHistory(sortedHistory: [HistoryEntry]) {
        // If the last entry is pinned, there is nothing we can collect.
        guard !sortedHistory.isEmpty && !sortedHistory.last!.isPinned else {
            return
        }
        
        let originalCount = sortedHistory.count
        
        var reducedHistory = sortedHistory
        
        let cutoff = Date.now.addingTimeInterval(TimeInterval(-maxAgeInDays * 24 * 60 * 60))
        if let i = reducedHistory.firstIndex(where: { !$0.isPinned && $0.lastUsedDate < cutoff }) {
            reducedHistory = Array(reducedHistory[..<i])
        }
    
        if reducedHistory.count > hardLimit,
           let i = reducedHistory.firstIndex(where: { !$0.isPinned }) {
            reducedHistory = Array(reducedHistory[..<max(i, softLimit)])
        }
        
        if reducedHistory.count != originalCount {
            historyByFilter = reducedHistory.reduce(into: [:]) { dict, entry in
                dict[entry.filter] = entry
            }
            saveHistory()
            
            print("Garbage collected \(reducedHistory.count - originalCount) history entries")
        }
    }

    // MARK: - Persistence

    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(historyByFilter)
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
            historyByFilter = try decoder.decode([SearchFilter: HistoryEntry].self, from: data)
        } catch {
            print("Failed to load filter history: \(error)")
            historyByFilter = [:]
        }
    }
}
