//
//  PinnedFilterAutocompleteProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-18.
//

import Foundation
import Observation

struct PinnedFilterSuggestion: Equatable, Sendable, ScorableSuggestion {
    let filter: SearchFilter
    let matchRange: Range<String.Index>?
    let prefixKind: PrefixKind
    let suggestionLength: Int
}

struct PinnedFilterEntry: Codable {
    let filter: SearchFilter
    let pinnedDate: Date
    let lastUsedDate: Date
}

@Observable
class PinnedFilterSuggestionProvider {
    // MARK: - Properties
    
    private(set) var pinnedFiltersByFilter: [SearchFilter: PinnedFilterEntry] = [:]
    
    // TODO: Is this really the right way to do persistence? Should I dependecy-inject it?
    private let persistenceKey: String
    
    // MARK: - Initialization
    
    init(persistenceKey: String = "pinnedFilters") {
        self.persistenceKey = persistenceKey
        loadPinnedFilters()
    }
    
    // MARK: - Public Methods
    
    func getSuggestions(for partial: PartialSearchFilter, excluding excludedFilters: Set<SearchFilter>) -> [PinnedFilterSuggestion] {
        let searchTerm = partial.description.trimmingCharacters(in: .whitespaces)
        
        return pinnedFiltersByFilter
            .values
            .sorted(using: [
                KeyPathComparator(\.pinnedDate, order: .reverse),
                KeyPathComparator(\.lastUsedDate, order: .reverse),
                KeyPathComparator(\.filter.description, comparator: .localizedStandard),
            ])
            .filter { !excludedFilters.contains($0.filter) }
            .compactMap { entry in
                let filterText = entry.filter.description

                if searchTerm.isEmpty {
                    return PinnedFilterSuggestion(
                        filter: entry.filter,
                        matchRange: nil,
                        // TODO: Would .actual produce better results?
                        prefixKind: .none,
                        suggestionLength: filterText.count,
                    )
                }
                
                if let range = filterText.range(of: searchTerm, options: .caseInsensitive) {
                    return PinnedFilterSuggestion(
                        filter: entry.filter,
                        matchRange: range,
                        prefixKind: range.lowerBound == filterText.startIndex ? .actual : .none,
                        suggestionLength: filterText.count,
                    )
                }
                
                return nil
            }
    }
    
    func pin(filter: SearchFilter) {
        let now = Date.now
        
        // If already pinned, update the lastUsedDate but keep the original pinnedDate
        if let existing = pinnedFiltersByFilter[filter] {
            let entry = PinnedFilterEntry(
                filter: filter,
                pinnedDate: existing.pinnedDate,
                lastUsedDate: now
            )
            pinnedFiltersByFilter[filter] = entry
        } else {
            // New pin
            let entry = PinnedFilterEntry(
                filter: filter,
                pinnedDate: now,
                lastUsedDate: now
            )
            pinnedFiltersByFilter[filter] = entry
        }
        
        savePinnedFilters()
    }
    
    func unpin(filter: SearchFilter) {
        pinnedFiltersByFilter.removeValue(forKey: filter)
        savePinnedFilters()
    }
    
    func recordUsage(of filter: SearchFilter) {
        guard var entry = pinnedFiltersByFilter[filter] else { return }
        
        entry = PinnedFilterEntry(
            filter: entry.filter,
            pinnedDate: entry.pinnedDate,
            lastUsedDate: Date.now
        )
        pinnedFiltersByFilter[filter] = entry
        savePinnedFilters()
    }
    
    func isPinned(_ filter: SearchFilter) -> Bool {
        return pinnedFiltersByFilter[filter] != nil
    }
    
    func delete(filter: SearchFilter) {
        pinnedFiltersByFilter.removeValue(forKey: filter)
        savePinnedFilters()
    }
    
    // MARK: - Persistence
    
    private func savePinnedFilters() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(pinnedFiltersByFilter)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            print("Failed to save pinned filters: \(error)")
        }
    }
    
    private func loadPinnedFilters() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            pinnedFiltersByFilter = try decoder.decode([SearchFilter: PinnedFilterEntry].self, from: data)
        } catch {
            print("Failed to load pinned filters: \(error)")
            pinnedFiltersByFilter = [:]
        }
    }
}
