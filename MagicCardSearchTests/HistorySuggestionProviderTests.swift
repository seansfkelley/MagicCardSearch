//
//  HistorySuggestionProviderTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-12.
//

import Testing
import Foundation
@testable import MagicCardSearch

struct HistorySuggestionProviderTests {
    var provider: HistorySuggestionProvider
    
    init() {
        provider = HistorySuggestionProvider(persistenceKey: UUID().uuidString)
    }
    
    private func recordUsages(of filters: [SearchFilter]) {
        for filter in filters {
            provider.recordUsage(of: filter)
        }
    }
    
    // MARK: - Basic Functionality Tests
    
    @Test("empty provider returns no suggestions")
    func emptySuggestions() {
        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
        #expect(suggestions.isEmpty)
    }
    
    @Test("returns all filters below the limit if no search term is provided")
    func emptySearchText() {
        let colorFilter = SearchFilter.basic(.keyValue("color", .equal, "red"))
        let oracleFilter = SearchFilter.basic(.keyValue("oracle", .including, "flying"))
        recordUsages(of: [colorFilter, oracleFilter])
        
        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 1)
        // Prefers the latter, because it was recorded later.
        #expect(suggestions == [HistorySuggestion(filter: oracleFilter, isPinned: false, matchRange: nil)])
    }
    
    @Test("returns pinned filters before non-pinned filters that were recorded later")
    func emptySearchTextWithPinned() {
        let colorFilter = SearchFilter.basic(.keyValue("color", .equal, "red"))
        provider.recordUsage(of: colorFilter)
        provider.pin(filter: colorFilter)
        
        let oracleFilter = SearchFilter.basic(.keyValue("oracle", .including, "flying"))
        provider.recordUsage(of: oracleFilter)
        
        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 1)
        #expect(suggestions == [HistorySuggestion(filter: colorFilter, isPinned: true, matchRange: nil)])
    }
    
//    // MARK: - Sorting Tests
//    
//    @Test("Sorts by last used date")
//    func sortsByLastUsedDate() async throws {
//        let provider = createProvider()
//        let oldFilter = makeFilter("color=red")
//        let newFilter = makeFilter("color=blue")
//        
//        provider.recordFilterUsage(oldFilter)
//        
//        // Wait a bit to ensure different timestamps
//        try await Task.sleep(for: .milliseconds(10))
//        
//        provider.recordFilterUsage(newFilter)
//        
//        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
//        #expect(suggestions.count == 2)
//        #expect(first.filter == newFilter)
//        #expect(second.filter == oldFilter)
//    }
//    
//    @Test("Pinned items appear first")
//    func pinnedItemsFirst() async throws {
//        let provider = createProvider()
//        let unpinnedFilter = makeFilter("color=red")
//        let pinnedFilter = makeFilter("color=blue")
//        
//        provider.recordFilterUsage(unpinnedFilter)
//        
//        try await Task.sleep(for: .milliseconds(10))
//        
//        provider.recordFilterUsage(pinnedFilter)
//        provider.pinSearchFilter(pinnedFilter)
//        
//        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
//        #expect(suggestions.count == 2)
//        #expect(first.filter == pinnedFilter)
//        #expect(first.isPinned == true)
//        #expect(second.filter == unpinnedFilter)
//        #expect(second.isPinned == false)
//    }
//    
//    @Test("Sorts alphabetically when dates are equal")
//    func alphabeticalSorting() {
//        let provider = createProvider()
//        let filterA = makeFilter("color=red")
//        let filterB = makeFilter("type=creature")
//        
//        // Record at same time
//        let date = Date()
//        provider.recordFilterUsage(filterB)
//        provider.recordFilterUsage(filterA)
//        
//        // Both should have very similar timestamps, alphabetical ordering should take effect
//        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
//        #expect(suggestions.count == 2)
//    }
//    
//    // MARK: - Search/Filtering Tests
//    
//    @Test("Filters by search term")
//    func searchTermFiltering() {
//        let provider = createProvider()
//        provider.recordFilterUsage(makeFilter("color=red"))
//        provider.recordFilterUsage(makeFilter("type=creature"))
//        provider.recordFilterUsage(makeFilter("manavalue=3"))
//        
//        let suggestions = provider.getSuggestions(for: "col", excluding: Set(), limit: 10)
//        #expect(suggestions.count == 1)
//        #expect(suggestion.filter == makeFilter("color=red"))
//        #expect(suggestion.matchRange != nil)
//    }
//    
//    @Test("Case insensitive search")
//    func caseInsensitiveSearch() {
//        let provider = createProvider()
//        provider.recordFilterUsage(makeFilter("color=red"))
//        
//        let suggestions = provider.getSuggestions(for: "COL", excluding: Set(), limit: 10)
//        #expect(suggestions.count == 1)
//        #expect(suggestion.matchRange != nil)
//    }
//    
//    @Test("Substring matching")
//    func substringMatching() {
//        let provider = createProvider()
//        provider.recordFilterUsage(makeFilter("manavalue=3"))
//        
//        let suggestions = provider.getSuggestions(for: "value", excluding: Set(), limit: 10)
//        #expect(suggestions.count == 1)
//    }
//    
//    @Test("Excludes existing filters")
//    func excludesExcluding() {
//        let provider = createProvider()
//        let filter1 = makeFilter("color=red")
//        let filter2 = makeFilter("type=creature")
//        
//        provider.recordFilterUsage(filter1)
//        provider.recordFilterUsage(filter2)
//        
//        let suggestions = provider.getSuggestions(for: "", excluding: [filter1], limit: 10)
//        #expect(suggestions.count == 1)
//        #expect(suggestion.filter == filter2)
//    }
//    
//    @Test("Respects limit")
//    func respectsLimit() {
//        let provider = createProvider()
//        provider.recordFilterUsage(makeFilter("color=red"))
//        provider.recordFilterUsage(makeFilter("type=creature"))
//        provider.recordFilterUsage(makeFilter("manavalue=3"))
//        
//        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 2)
//        #expect(suggestions.count == 2)
//    }
//    
//    @Test("Limit applies after filtering")
//    func limitAfterFiltering() {
//        let provider = createProvider()
//        provider.recordFilterUsage(makeFilter("color=red"))
//        provider.recordFilterUsage(makeFilter("color=blue"))
//        provider.recordFilterUsage(makeFilter("type=creature"))
//        
//        let suggestions = provider.getSuggestions(for: "color", excluding: Set(), limit: 1)
//        #expect(suggestions.count == 1)
//        #expect(suggestion.filter == makeFilter("color=blue"))
//    }
//    
//    // MARK: - Pin/Unpin Tests
//    
//    @Test("Pin changes isPinned flag")
//    func pinChangesFlag() {
//        let provider = createProvider()
//        let filter = makeFilter("color=red")
//        
//        provider.recordFilterUsage(filter)
//        provider.pinSearchFilter(filter)
//        
//        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
//        #expect(suggestion.isPinned == true)
//    }
//    
//    @Test("Unpin changes isPinned flag")
//    func unpinChangesFlag() {
//        let provider = createProvider()
//        let filter = makeFilter("color=red")
//        
//        provider.recordFilterUsage(filter)
//        provider.pinSearchFilter(filter)
//        provider.unpinSearchFilter(filter)
//        
//        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
//        #expect(suggestion.isPinned == false)
//    }
//    
//    @Test("Pin preserves filter across new recordings")
//    func pinPreservedAcrossRecordings() {
//        let provider = createProvider()
//        let filter = makeFilter("color=red")
//        
//        provider.recordFilterUsage(filter)
//        provider.pinSearchFilter(filter)
//        provider.recordFilterUsage(filter) // Record again
//        
//        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
//        #expect(suggestion.isPinned == true)
//    }
//    
//    // MARK: - Deletion Tests
//    
//    @Test("Delete removes filter")
//    func deleteRemovesFilter() {
//        let provider = createProvider()
//        let filter = makeFilter("color=red")
//        
//        provider.recordFilterUsage(filter)
//        #expect((provider.getSuggestions(for: "", excluding: Set(), limit: 10)).count == 1)
//        
//        provider.deleteSearchFilter(filter)
//        #expect((provider.getSuggestions(for: "", excluding: Set(), limit: 10)).isEmpty)
//    }
//    
//    @Test("Delete only removes specified filter")
//    func deleteOnlySpecifiedFilter() {
//        let provider = createProvider()
//        let filter1 = makeFilter("color=red")
//        let filter2 = makeFilter("type=creature")
//        
//        provider.recordFilterUsage(filter1)
//        provider.recordFilterUsage(filter2)
//        
//        provider.deleteSearchFilter(filter1)
//        
//        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
//        #expect(suggestions.count == 1)
//        #expect(suggestion.filter == filter2)
//    }
//    
//    // MARK: - Update Tests
//    
//    @Test("Recording same filter updates its timestamp")
//    func recordingUpdatesTimestamp() async throws {
//        let provider = createProvider()
//        let filter = makeFilter("color=red")
//        let otherFilter = makeFilter("type=creature")
//        
//        provider.recordFilterUsage(filter)
//        provider.recordFilterUsage(otherFilter)
//        
//        // At this point, otherFilter is most recent
//        var suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
//        #expect(first.filter == otherFilter)
//        
//        try await Task.sleep(for: .milliseconds(10))
//        
//        // Record filter again
//        provider.recordFilterUsage(filter)
//        
//        // Now filter should be most recent
//        suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
//        #expect(newFirst.filter == filter)
//    }
//    
//    // MARK: - Edge Cases
//    
//    @Test("Whitespace-only search term returns all")
//    func whitespaceSearchTerm() {
//        let provider = createProvider()
//        provider.recordFilterUsage(makeFilter("color=red"))
//        
//        let suggestions = provider.getSuggestions(for: "   ", excluding: Set(), limit: 10)
//        #expect(suggestions.count == 1)
//    }
//    
//    @Test("Empty search term returns all")
//    func emptySearchTerm() {
//        let provider = createProvider()
//        provider.recordFilterUsage(makeFilter("color=red"))
//        
//        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
//        #expect(suggestions.count == 1)
//    }
//    
//    @Test("No match returns empty")
//    func noMatchReturnsEmpty() {
//        let provider = createProvider()
//        provider.recordFilterUsage(makeFilter("color=red"))
//        
//        let suggestions = provider.getSuggestions(for: "xyzzyx", excluding: Set(), limit: 10)
//        #expect(suggestions.isEmpty)
//    }
}
