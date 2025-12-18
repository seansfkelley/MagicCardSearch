//
//  SearchResultsState.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-18.
//

import Foundation
import Observation

@MainActor
@Observable
class SearchResultsState {
    var results: LoadableResult<SearchResults, SearchErrorState>
    private let searchService = CardSearchService()
    
    init(results: LoadableResult<SearchResults, SearchErrorState> = .unloaded) {
        self.results = results
    }
    
    func loadNextPageIfNeeded() {
        guard case .loaded(let searchResults, _) = results,
              let nextUrl = searchResults.nextPageUrl else {
            return
        }
        
        print("Loading next page \(nextUrl)")
        
        results = .loading(searchResults, nil)
        
        Task {
            do {
                let searchResult = try await searchService.fetchNextPage(from: nextUrl)
                let updatedResults = SearchResults(
                    totalCount: searchResults.totalCount,
                    cards: searchResults.cards + searchResult.cards,
                    warnings: searchResults.warnings,
                    nextPageUrl: searchResult.nextPageURL
                )
                results = .loaded(updatedResults, nil)
            } catch {
                print("Error loading next page: \(error)")
                results = .errored(searchResults, SearchErrorState(from: error))
            }
        }
    }
    
    func retryNextPage() {
        if case .errored(let value, _) = results, let searchResults = value {
            results = .loaded(searchResults, nil)
            loadNextPageIfNeeded()
        }
    }
}
