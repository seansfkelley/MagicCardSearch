//
//  HistorySuggestionProviderTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-12.
//

import Testing
import Foundation
@testable import MagicCardSearch

@Suite
class HistorySuggestionProviderTests {
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
        #expect(suggestions == [.init(filter: oracleFilter, isPinned: false, matchRange: nil)])
    }
    
    @Test("returns pinned filters before non-pinned filters that were recorded later")
    func emptySearchTextWithPinned() {
        let colorFilter = SearchFilter.basic(.keyValue("color", .equal, "red"))
        provider.recordUsage(of: colorFilter)
        provider.pin(filter: colorFilter)
        
        let oracleFilter = SearchFilter.basic(.keyValue("oracle", .including, "flying"))
        provider.recordUsage(of: oracleFilter)
        
        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 1)
        #expect(suggestions == [.init(filter: colorFilter, isPinned: true, matchRange: nil)])
    }
    
    @Test("should not delete any filters if the soft limit but not the hard limit is reached")
    func testSoftLimit() {
        provider = HistorySuggestionProvider(
            hardLimit: 2,
            softLimit: 1,
            persistenceKey: UUID().uuidString
        )
        
        let colorFilter = SearchFilter.basic(.keyValue("color", .equal, "red"))
        let oracleFilter = SearchFilter.basic(.keyValue("oracle", .including, "flying"))
        recordUsages(of: [colorFilter, oracleFilter])
        
        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
        #expect(suggestions == [
            .init(filter: oracleFilter, isPinned: false, matchRange: nil),
            .init(filter: colorFilter, isPinned: false, matchRange: nil),
        ])
    }
    
    @Test("deletes the oldest filters beyond the soft limit if the hard limit is reached")
    func testHardLimit() {
        provider = HistorySuggestionProvider(
            hardLimit: 2,
            softLimit: 1,
            persistenceKey: UUID().uuidString
        )
        
        let colorFilter = SearchFilter.basic(.keyValue("color", .equal, "red"))
        let oracleFilter = SearchFilter.basic(.keyValue("oracle", .including, "flying"))
        let setFilter = SearchFilter.basic(.keyValue("set", .equal, "ody"))
        recordUsages(of: [colorFilter, oracleFilter, setFilter])
        
        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
        #expect(suggestions == [
            .init(filter: setFilter, isPinned: false, matchRange: nil),
        ])
    }
    
    @Test("does not delete filters beyond the hard limit if they are pinned")
    func testHardLimitWithPinned() {
        provider = HistorySuggestionProvider(
            hardLimit: 2,
            softLimit: 1,
            persistenceKey: UUID().uuidString
        )
        
        let colorFilter = SearchFilter.basic(.keyValue("color", .equal, "red"))
        provider.recordUsage(of: colorFilter)
        provider.pin(filter: colorFilter)
        let oracleFilter = SearchFilter.basic(.keyValue("oracle", .including, "flying"))
        provider.recordUsage(of: oracleFilter)
        provider.pin(filter: oracleFilter)
        let setFilter = SearchFilter.basic(.keyValue("set", .equal, "ody"))
        provider.recordUsage(of: setFilter)
        provider.pin(filter: setFilter)
        
        provider.recordUsage(of: SearchFilter.basic(.keyValue("function", .including, "flicker")))
        
        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
        #expect(suggestions == [
            .init(filter: setFilter, isPinned: true, matchRange: nil),
            .init(filter: oracleFilter, isPinned: true, matchRange: nil),
            .init(filter: colorFilter, isPinned: true, matchRange: nil),
        ])
    }
    
    @Test("returns any filters whose string representation has any substring match")
    func substringMatch() {
        let colorFilter = SearchFilter.basic(.keyValue("color", .equal, "red"))
        let oracleFilter = SearchFilter.basic(.keyValue("oracle", .including, "flying"))
        let setFilter = SearchFilter.basic(.keyValue("set", .equal, "odyssey"))
        recordUsages(of: [colorFilter, oracleFilter, setFilter])
        
        let suggestions = provider.getSuggestions(for: "y", excluding: Set(), limit: 10)
        #expect(suggestions == [
            .init(filter: setFilter, isPinned: false, matchRange: "set:ody".range(of: "y")),
            .init(filter: oracleFilter, isPinned: false, matchRange: "oracle:flying".range(of: "y")),
        ])
    }
    
    @Test("returns exclude matching filters present in the exclusion list")
    func excludeMatchingFilters() {
        let colorFilter = SearchFilter.basic(.keyValue("color", .equal, "red"))
        let oracleFilter = SearchFilter.basic(.keyValue("oracle", .including, "flying"))
        let setFilter = SearchFilter.basic(.keyValue("set", .equal, "ody"))
        recordUsages(of: [colorFilter, oracleFilter, setFilter])
        
        let suggestions = provider.getSuggestions(for: "y", excluding: Set([oracleFilter]), limit: 10)
        #expect(suggestions == [
            .init(filter: setFilter, isPinned: false, matchRange: "set:ody".range(of: "y")),
        ])
    }
    
    @Test("returns the empty list if there is no simple substring match in the stringified filters")
    func noSubstringMatch() {
        let colorFilter = SearchFilter.basic(.keyValue("color", .equal, "red"))
        let oracleFilter = SearchFilter.basic(.keyValue("oracle", .including, "flying"))
        recordUsages(of: [colorFilter, oracleFilter])
        
        let suggestions = provider.getSuggestions(for: "xyz", excluding: Set(), limit: 10)
        #expect(suggestions.isEmpty)
    }
    
    @Test("does not implicitly add usages if pinning or unpinning filters that aren't recorded")
    func pinningWithoutRecording() {
        let colorFilter = SearchFilter.basic(.keyValue("color", .equal, "red"))
        
        provider.pin(filter: colorFilter)
        
        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
        #expect(suggestions.isEmpty)
        
        provider.unpin(filter: colorFilter)
        
        let suggestionsAfterUnpin = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
        #expect(suggestionsAfterUnpin.isEmpty)
    }
    
    @Test("does nothing if deleting a filter that does not exist")
    func deleteNonexistent() {
        let colorFilter = SearchFilter.basic(.keyValue("color", .equal, "red"))
        let oracleFilter = SearchFilter.basic(.keyValue("oracle", .including, "flying"))
        recordUsages(of: [colorFilter])
        
        provider.delete(filter: oracleFilter)
        
        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
        #expect(suggestions == [.init(filter: colorFilter, isPinned: false, matchRange: nil)])
    }
}
