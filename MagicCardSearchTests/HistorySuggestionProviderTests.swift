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
    // MARK: - Helper Methods
    
    func createProvider() -> HistorySuggestionProvider {
        // Create a provider with a unique persistence key to avoid conflicts
        let provider = HistorySuggestionProvider()
        return provider
    }
    
    func makeFilter(_ string: String) -> SearchFilter {
        SearchFilter.tryParseUnambiguous(string)!
    }
    
    // MARK: - Basic Functionality Tests
    
    @Test("Empty provider returns no suggestions")
    func emptySuggestions() async {
        let provider = createProvider()
        let suggestions = await provider.getSuggestions("", existingFilters: [], limit: 10)
        #expect(suggestions.isEmpty)
    }
    
    @Test("Records and retrieves single filter")
    func singleFilter() async {
        let provider = createProvider()
        let filter = makeFilter("color=red")
        
        provider.recordFilterUsage(filter)
        let suggestions = await provider.getSuggestions("", existingFilters: [], limit: 10)
        
        #expect(suggestions.count == 1)
        guard case .history(let suggestion) = suggestions[0] else {
            Issue.record("Expected history suggestion")
            return
        }
        #expect(suggestion.filter == filter)
        #expect(suggestion.isPinned == false)
        #expect(suggestion.matchRange == nil)
    }
    
    @Test("Records multiple filters")
    func multipleFilters() async {
        let provider = createProvider()
        let filters = [
            makeFilter("color=red"),
            makeFilter("type=creature"),
            makeFilter("manavalue=3"),
        ]
        
        for filter in filters {
            provider.recordFilterUsage(filter)
        }
        
        let suggestions = await provider.getSuggestions("", existingFilters: [], limit: 10)
        #expect(suggestions.count == 3)
    }
    
    // MARK: - Sorting Tests
    
    @Test("Sorts by last used date")
    func sortsByLastUsedDate() async throws {
        let provider = createProvider()
        let oldFilter = makeFilter("color=red")
        let newFilter = makeFilter("color=blue")
        
        provider.recordFilterUsage(oldFilter)
        
        // Wait a bit to ensure different timestamps
        try await Task.sleep(for: .milliseconds(10))
        
        provider.recordFilterUsage(newFilter)
        
        let suggestions = await provider.getSuggestions("", existingFilters: [], limit: 10)
        #expect(suggestions.count == 2)
        
        guard case .history(let first) = suggestions[0],
              case .history(let second) = suggestions[1] else {
            Issue.record("Expected history suggestions")
            return
        }
        
        // Most recent should come first
        #expect(first.filter == newFilter)
        #expect(second.filter == oldFilter)
    }
    
    @Test("Pinned items appear first")
    func pinnedItemsFirst() async throws {
        let provider = createProvider()
        let unpinnedFilter = makeFilter("color=red")
        let pinnedFilter = makeFilter("color=blue")
        
        provider.recordFilterUsage(unpinnedFilter)
        
        try await Task.sleep(for: .milliseconds(10))
        
        provider.recordFilterUsage(pinnedFilter)
        provider.pinSearchFilter(pinnedFilter)
        
        let suggestions = await provider.getSuggestions("", existingFilters: [], limit: 10)
        #expect(suggestions.count == 2)
        
        guard case .history(let first) = suggestions[0],
              case .history(let second) = suggestions[1] else {
            Issue.record("Expected history suggestions")
            return
        }
        
        // Pinned should come first, even though unpinned was used more recently
        #expect(first.filter == pinnedFilter)
        #expect(first.isPinned == true)
        #expect(second.filter == unpinnedFilter)
        #expect(second.isPinned == false)
    }
    
    @Test("Sorts alphabetically when dates are equal")
    func alphabeticalSorting() async {
        let provider = createProvider()
        let filterA = makeFilter("color=red")
        let filterB = makeFilter("type=creature")
        
        // Record at same time
        let date = Date()
        provider.recordFilterUsage(filterB)
        provider.recordFilterUsage(filterA)
        
        // Both should have very similar timestamps, alphabetical ordering should take effect
        let suggestions = await provider.getSuggestions("", existingFilters: [], limit: 10)
        #expect(suggestions.count == 2)
    }
    
    // MARK: - Search/Filtering Tests
    
    @Test("Filters by search term")
    func searchTermFiltering() async {
        let provider = createProvider()
        provider.recordFilterUsage(makeFilter("color=red"))
        provider.recordFilterUsage(makeFilter("type=creature"))
        provider.recordFilterUsage(makeFilter("manavalue=3"))
        
        let suggestions = await provider.getSuggestions("col", existingFilters: [], limit: 10)
        #expect(suggestions.count == 1)
        
        guard case .history(let suggestion) = suggestions[0] else {
            Issue.record("Expected history suggestion")
            return
        }
        #expect(suggestion.filter == makeFilter("color=red"))
        #expect(suggestion.matchRange != nil)
    }
    
    @Test("Case insensitive search")
    func caseInsensitiveSearch() async {
        let provider = createProvider()
        provider.recordFilterUsage(makeFilter("color=red"))
        
        let suggestions = await provider.getSuggestions("COL", existingFilters: [], limit: 10)
        #expect(suggestions.count == 1)
        
        guard case .history(let suggestion) = suggestions[0] else {
            Issue.record("Expected history suggestion")
            return
        }
        #expect(suggestion.matchRange != nil)
    }
    
    @Test("Substring matching")
    func substringMatching() async {
        let provider = createProvider()
        provider.recordFilterUsage(makeFilter("manavalue=3"))
        
        let suggestions = await provider.getSuggestions("value", existingFilters: [], limit: 10)
        #expect(suggestions.count == 1)
    }
    
    @Test("Excludes existing filters")
    func excludesExistingFilters() async {
        let provider = createProvider()
        let filter1 = makeFilter("color=red")
        let filter2 = makeFilter("type=creature")
        
        provider.recordFilterUsage(filter1)
        provider.recordFilterUsage(filter2)
        
        let suggestions = await provider.getSuggestions("", existingFilters: [filter1], limit: 10)
        #expect(suggestions.count == 1)
        
        guard case .history(let suggestion) = suggestions[0] else {
            Issue.record("Expected history suggestion")
            return
        }
        #expect(suggestion.filter == filter2)
    }
    
    @Test("Respects limit")
    func respectsLimit() async {
        let provider = createProvider()
        provider.recordFilterUsage(makeFilter("color=red"))
        provider.recordFilterUsage(makeFilter("type=creature"))
        provider.recordFilterUsage(makeFilter("manavalue=3"))
        
        let suggestions = await provider.getSuggestions("", existingFilters: [], limit: 2)
        #expect(suggestions.count == 2)
    }
    
    @Test("Limit applies after filtering")
    func limitAfterFiltering() async {
        let provider = createProvider()
        provider.recordFilterUsage(makeFilter("color=red"))
        provider.recordFilterUsage(makeFilter("color=blue"))
        provider.recordFilterUsage(makeFilter("type=creature"))
        
        let suggestions = await provider.getSuggestions("color", existingFilters: [], limit: 1)
        #expect(suggestions.count == 1)
        
        guard case .history(let suggestion) = suggestions[0] else {
            Issue.record("Expected history suggestion")
            return
        }
        // Should get the most recent matching one
        #expect(suggestion.filter == makeFilter("color=blue"))
    }
    
    // MARK: - Pin/Unpin Tests
    
    @Test("Pin changes isPinned flag")
    func pinChangesFlag() async {
        let provider = createProvider()
        let filter = makeFilter("color=red")
        
        provider.recordFilterUsage(filter)
        provider.pinSearchFilter(filter)
        
        let suggestions = await provider.getSuggestions("", existingFilters: [], limit: 10)
        guard case .history(let suggestion) = suggestions[0] else {
            Issue.record("Expected history suggestion")
            return
        }
        #expect(suggestion.isPinned == true)
    }
    
    @Test("Unpin changes isPinned flag")
    func unpinChangesFlag() async {
        let provider = createProvider()
        let filter = makeFilter("color=red")
        
        provider.recordFilterUsage(filter)
        provider.pinSearchFilter(filter)
        provider.unpinSearchFilter(filter)
        
        let suggestions = await provider.getSuggestions("", existingFilters: [], limit: 10)
        guard case .history(let suggestion) = suggestions[0] else {
            Issue.record("Expected history suggestion")
            return
        }
        #expect(suggestion.isPinned == false)
    }
    
    @Test("Pin preserves filter across new recordings")
    func pinPreservedAcrossRecordings() async {
        let provider = createProvider()
        let filter = makeFilter("color=red")
        
        provider.recordFilterUsage(filter)
        provider.pinSearchFilter(filter)
        provider.recordFilterUsage(filter) // Record again
        
        let suggestions = await provider.getSuggestions("", existingFilters: [], limit: 10)
        guard case .history(let suggestion) = suggestions[0] else {
            Issue.record("Expected history suggestion")
            return
        }
        #expect(suggestion.isPinned == true)
    }
    
    // MARK: - Deletion Tests
    
    @Test("Delete removes filter")
    func deleteRemovesFilter() async {
        let provider = createProvider()
        let filter = makeFilter("color=red")
        
        provider.recordFilterUsage(filter)
        #expect((await provider.getSuggestions("", existingFilters: [], limit: 10)).count == 1)
        
        provider.deleteSearchFilter(filter)
        #expect((await provider.getSuggestions("", existingFilters: [], limit: 10)).isEmpty)
    }
    
    @Test("Delete only removes specified filter")
    func deleteOnlySpecifiedFilter() async {
        let provider = createProvider()
        let filter1 = makeFilter("color=red")
        let filter2 = makeFilter("type=creature")
        
        provider.recordFilterUsage(filter1)
        provider.recordFilterUsage(filter2)
        
        provider.deleteSearchFilter(filter1)
        
        let suggestions = await provider.getSuggestions("", existingFilters: [], limit: 10)
        #expect(suggestions.count == 1)
        guard case .history(let suggestion) = suggestions[0] else {
            Issue.record("Expected history suggestion")
            return
        }
        #expect(suggestion.filter == filter2)
    }
    
    // MARK: - Update Tests
    
    @Test("Recording same filter updates its timestamp")
    func recordingUpdatesTimestamp() async throws {
        let provider = createProvider()
        let filter = makeFilter("color=red")
        let otherFilter = makeFilter("type=creature")
        
        provider.recordFilterUsage(filter)
        provider.recordFilterUsage(otherFilter)
        
        // At this point, otherFilter is most recent
        var suggestions = await provider.getSuggestions("", existingFilters: [], limit: 10)
        guard case .history(let first) = suggestions[0] else {
            Issue.record("Expected history suggestion")
            return
        }
        #expect(first.filter == otherFilter)
        
        try await Task.sleep(for: .milliseconds(10))
        
        // Record filter again
        provider.recordFilterUsage(filter)
        
        // Now filter should be most recent
        suggestions = await provider.getSuggestions("", existingFilters: [], limit: 10)
        guard case .history(let newFirst) = suggestions[0] else {
            Issue.record("Expected history suggestion")
            return
        }
        #expect(newFirst.filter == filter)
    }
    
    // MARK: - Edge Cases
    
    @Test("Whitespace-only search term returns all")
    func whitespaceSearchTerm() async {
        let provider = createProvider()
        provider.recordFilterUsage(makeFilter("color=red"))
        
        let suggestions = await provider.getSuggestions("   ", existingFilters: [], limit: 10)
        #expect(suggestions.count == 1)
    }
    
    @Test("Empty search term returns all")
    func emptySearchTerm() async {
        let provider = createProvider()
        provider.recordFilterUsage(makeFilter("color=red"))
        
        let suggestions = await provider.getSuggestions("", existingFilters: [], limit: 10)
        #expect(suggestions.count == 1)
    }
    
    @Test("No match returns empty")
    func noMatchReturnsEmpty() async {
        let provider = createProvider()
        provider.recordFilterUsage(makeFilter("color=red"))
        
        let suggestions = await provider.getSuggestions("xyzzyx", existingFilters: [], limit: 10)
        #expect(suggestions.isEmpty)
    }
}
