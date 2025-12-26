//
//  SearchHistoryTracker.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-18.
//
import Foundation
import Observation
import Logging

private let logger = Logger(label: "SearchHistoryTracker")

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

    private var sideEffectDepth = 0
    private let hardLimit: Int
    private let softLimit: Int
    private let maxAgeInDays: Int
    // TODO: Is this really the right way to do persistence? Should I dependecy-inject it?
    private let persistenceKey: String
    
    private var cachedSortedFilterEntries: [FilterEntry]?
    var sortedFilterEntries: [FilterEntry] {
        if let cachedSortedFilterEntries {
            return cachedSortedFilterEntries
        }

        let sorted = filterEntries.values.sorted(using: [
            KeyPathComparator(\.lastUsedDate, order: .reverse),
            KeyPathComparator(\.filter.description, comparator: .localizedStandard),
        ])
        cachedSortedFilterEntries = sorted
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
        withSideEffects {
            func recursivelyRecordDisjunctions(_ disjunction: SearchFilter.Disjunction) {
                for disjunctionClause in disjunction.clauses {
                    for conjunctionClause in disjunctionClause.clauses {
                        switch conjunctionClause {
                        case .filter(let filter): recordUsage(of: filter)
                        case .disjunction(let disjunction): recursivelyRecordDisjunctions(disjunction)
                        }
                    }
                }
            }

            if case .disjunction(let disjunction) = filter {
                recursivelyRecordDisjunctions(disjunction)
            }

            filterEntries[filter] = FilterEntry(
                filter: filter,
                lastUsedDate: Date(),
            )
        }
    }

    func recordSearch(with filters: [SearchFilter]) {
        withSideEffects {
            if let existingIndex = completeSearchEntries.firstIndex(where: { $0.filters == filters }) {
                completeSearchEntries.remove(at: existingIndex)
            }

            completeSearchEntries.insert(
                CompleteSearchEntry(
                    filters: filters,
                    lastUsedDate: Date()
                ),
                at: 0,
            )

            for filter in filters {
                recordUsage(of: filter)
            }
        }
    }

    func deleteUsage(of filter: SearchFilter) {
        withSideEffects {
            filterEntries.removeValue(forKey: filter)
        }
    }
    
    func deleteSearch(with filters: [SearchFilter]) {
        if let index = completeSearchEntries.firstIndex(where: { $0.filters == filters }) {
            withSideEffects {
                completeSearchEntries.remove(at: index)
            }
        }
    }

    private func withSideEffects(_ mutation: () -> Void) {
        sideEffectDepth += 1

        mutation()

        sideEffectDepth -= 1
        if sideEffectDepth == 0 {
            cachedSortedFilterEntries = nil
            saveHistory()
        } else {
            logger.debug("not committing changes as we aren't the top-most side-effect", metadata: [
                "depth": "\(sideEffectDepth)",
            ])
        }
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

        if !sortedFilterEntries.isEmpty {
            let originalCount = sortedFilterEntries.count
            let reducedHistory = truncateByAgeAndSize(sortedFilterEntries) { $0.lastUsedDate }
            
            if reducedHistory.count != originalCount {
                filterEntries = reducedHistory.reduce(into: [:]) { dict, entry in
                    dict[entry.filter] = entry
                }
                cachedSortedFilterEntries = nil
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
