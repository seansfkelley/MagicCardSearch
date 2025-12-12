//
//  AutcompleteProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import Foundation
import Observation

@Observable
class HistorySuggestionProvider: SuggestionProvider {
    // MARK: - Properties

    private var history: [HistoryEntry] = []
    private let maxHistoryCount = 1000
    private let persistenceKey = "filterHistory"

    // MARK: - Initialization

    init() {
        loadHistory()
    }

    // MARK: - Public Methods
    
    func getSuggestions(_ searchTerm: String, existingFilters: [SearchFilter])
    -> [Suggestion] {
        let availableHistory = history.filter { !existingFilters.contains($0.filter) }
        
        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespaces)
        
        if trimmedSearchTerm.isEmpty {
            let historySuggestions = availableHistory.map {
                HistorySuggestion(
                    filter: $0.filter,
                    isPinned: $0.isPinned,
                    matchRange: nil
                )
            }
            let historyLookup = Dictionary(uniqueKeysWithValues: availableHistory.map { ($0.filter, $0) })
            return Array(sortResults(historySuggestions, historyLookup: historyLookup).prefix(10)).map { .history($0) }
        }

        var results: [HistorySuggestion] = []

        for entry in availableHistory {
            let filterString = entry.filter.queryStringWithEditingRange.0
            if let range = filterString.range(of: trimmedSearchTerm, options: .caseInsensitive) {
                results.append(HistorySuggestion(
                    filter: entry.filter,
                    isPinned: entry.isPinned,
                    matchRange: range
                ))
            }
        }

        let historyLookup = Dictionary(uniqueKeysWithValues: availableHistory.map { ($0.filter, $0) })
        return Array(sortResults(results, historyLookup: historyLookup).prefix(10)).map { .history($0) }
    }

    // TODO: This implementation sucks.
    func recordFilterUsage(_ filter: SearchFilter) {
        let wasPinned = history.first { $0.filter == filter }?.isPinned ?? false
        let existingCounts = history.first { $0.filter == filter }?.counts ?? .new()

        history.removeAll { $0.filter == filter }

        let entry = HistoryEntry(
            filter: filter,
            counts: existingCounts.recordingUse(),
            isPinned: wasPinned
        )
        history.insert(entry, at: 0)

        history.removeAll { $0.counts.aged(to: Date()).isForgotten }
        
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }

        saveHistory()
    }

    // TODO: Weird interface; improve it. Also, slow.
    func pinSearchFilter(_ filter: SearchFilter) {
        if let i = history.firstIndex(where: { $0.filter == filter }) {
            let entry = history[i]
            history[i] = HistoryEntry(
                filter: entry.filter,
                // Pinning means we like it, so boost its score by promoting it here.
                counts: entry.counts.recordingUse(),
                isPinned: true
            )
            saveHistory()
        }
    }

    func unpinSearchFilter(_ filter: SearchFilter) {
        if let i = history.firstIndex(where: { $0.filter == filter }) {
            let entry = history[i]
            history[i] = HistoryEntry(
                filter: entry.filter,
                // If we just unpinned it, it would be surprising for it to fall way down the
                // list if we last it a while ago. Consider it recently used, and it will naturally
                // age out as we don't use it.
                counts: entry.counts.recordingUse(),
                isPinned: false
            )
            saveHistory()
        }
    }
    
    func deleteSearchFilter(_ filter: SearchFilter) {
        history.removeAll { $0.filter == filter }
        saveHistory()
    }

    // MARK: - Private Helpers

    private func sortResults(_ results: [HistorySuggestion], historyLookup: [SearchFilter: HistoryEntry]) -> [HistorySuggestion] {
        return results.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }

            // Score based on time-windowed usage counts
            let lhEntry = historyLookup[lhs.filter]
            let rhEntry = historyLookup[rhs.filter]
            
            let lhScore = lhEntry.map { TimeWindowedScorer.effectiveCount($0.counts) } ?? 0
            let rhScore = rhEntry.map { TimeWindowedScorer.effectiveCount($0.counts) } ?? 0
            
            return lhScore > rhScore
        }
    }

    // MARK: - Persistence

    private func saveHistory() {
        do {
            // TODO: JSON seems like the wrong thing; isn't there a Swift-native encoding?
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(history)
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
            history = try decoder.decode([HistoryEntry].self, from: data)
        } catch {
            print("Failed to load filter history: \(error)")
            history = []
        }
    }
}

struct HistoryEntry: Codable {
    let filter: SearchFilter
    let counts: TimeBucketedCounts
    let isPinned: Bool
}

/// Counts in overlapping time buckets (1d ⊂ 3d ⊂ 7d ⊂ 14d ⊂ 30d ⊂ 90d ⊂ 365d).
/// After 365 days, entries are forgotten (all counts become 0).
/// referenceDate tracks when counts were last accurate for lazy aging.
struct TimeBucketedCounts: Codable {
    let last1Day, last3Days, last7Days, last14Days, last30Days, last90Days, last365Days: Int
    let referenceDate: Date
    
    static func new() -> TimeBucketedCounts {
        TimeBucketedCounts(0, 0, 0, 0, 0, 0, 0, Date())
    }
    
    /// Age counts by shifting buckets based on elapsed time.
    /// Conservative: assumes all uses in a bucket happened at the oldest time.
    /// Buckets are inclusive (30d contains 7d), so we preserve the larger bucket.
    /// After 365 days, all counts become 0 (forgotten).
    func aged(to now: Date = Date()) -> TimeBucketedCounts {
        let days = abs(now.timeIntervalSince(referenceDate)) / 86400
        guard days >= 1 else { return self }
        
        switch days {
        case 365...: return .init(0, 0, 0, 0, 0, 0, 0, now)  // Forgotten
        case 90..<365: return .init(0, 0, 0, 0, 0, 0, last90Days, now)
        case 30..<90: return .init(0, 0, 0, 0, 0, last30Days, last90Days, now)
        case 14..<30: return .init(0, 0, 0, 0, last14Days, last30Days, last90Days, now)
        case 7..<14: return .init(0, 0, 0, last7Days, last14Days, last30Days, last90Days, now)
        case 3..<7: return .init(0, 0, last3Days, last7Days, last14Days, last30Days, last90Days, now)
        case 1..<3: return .init(0, last1Day, last3Days, last7Days, last14Days, last30Days, last90Days, now)
        default: return self
        }
    }
    
    /// Record a new use: age existing counts, then increment all buckets
    func recordingUse(at date: Date = Date()) -> TimeBucketedCounts {
        let aged = self.aged(to: date)
        return TimeBucketedCounts(
            aged.last1Day + 1,
            aged.last3Days + 1,
            aged.last7Days + 1,
            aged.last14Days + 1,
            aged.last30Days + 1,
            aged.last90Days + 1,
            aged.last365Days + 1,
            date
        )
    }
    
    /// Returns true if all counts are 0 (forgotten)
    var isForgotten: Bool {
        last365Days == 0
    }
    
    init(_ d1: Int, _ d3: Int, _ d7: Int, _ d14: Int, _ d30: Int, _ d90: Int, _ d365: Int, _ ref: Date) {
        (last1Day, last3Days, last7Days, last14Days, last30Days, last90Days, last365Days, referenceDate) =
            (d1, d3, d7, d14, d30, d90, d365, ref)
    }
}

// MARK: - Scoring

private struct TimeWindowedScorer {
    // ~Exponential decay.
    private let weights = (d1: 1.0, d3: 0.85, d7: 0.7, d14: 0.5, d30: 0.3, d90: 0.15, d365: 0.05)
    
    static func score(_ counts: TimeBucketedCounts) -> Double {
        // Lazy-age on access.
        let aged = counts.aged(to: Date())
        
        // Buckets are inclusive, that is, a usage today is considered a usage in all the time
        // ranges. This makes rolling them forward minimally lossy, but means we have to subtract
        // ranges like this to get what is unique to each span.
        let exclusive = (
            d1: aged.last1Day,
            d3: aged.last3Days - aged.last1Day,
            d7: aged.last7Days - aged.last3Days,
            d14: aged.last14Days - aged.last7Days,
            d30: aged.last30Days - aged.last14Days,
            d90: aged.last90Days - aged.last30Days,
            d365: aged.last365Days - aged.last90Days
        )
        
        return Double(exclusive.d1) * weights.d1 +
               Double(exclusive.d3) * weights.d3 +
               Double(exclusive.d7) * weights.d7 +
               Double(exclusive.d14) * weights.d14 +
               Double(exclusive.d30) * weights.d30 +
               Double(exclusive.d90) * weights.d90 +
               Double(exclusive.d365) * weights.d365
    }
}
