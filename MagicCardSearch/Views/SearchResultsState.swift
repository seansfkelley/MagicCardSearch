//
//  SearchResultsState.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-18.
//

import Foundation
import Observation
import Logging

private let logger = Logger(label: "SearchResultsState")

@MainActor
@Observable
class SearchResultsState {
    var results: LoadableResult<SearchResults, SearchErrorState>
    private let searchService = CardSearchService()
    
    init(results: LoadableResult<SearchResults, SearchErrorState> = .unloaded) {
        self.results = results
    }
    
    func loadNextPageIfNeeded() {
        guard case .loaded(let searchResults, _) = results else {
            logger.debug("Declining to load next page: not currently in loaded state")
            return
        }
        
        guard let nextUrl = searchResults.nextPageUrl else {
            logger.debug("Declining to load next page: no nextPageUrl")
            return
        }
        
        logger.info("Loading next page", metadata: [
            "nextPageUrl": "\(nextUrl)",
        ])
        
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
                logger.error("Error loading next page", metadata: [
                    "error": "\(error)",
                ])
                results = .errored(searchResults, SearchErrorState(from: error))
            }
        }
    }
    
    func retryNextPage() {
        guard case .errored(let searchResults, _) = results else {
            logger.debug("Declining to retry next page: not in errored state")
            return
        }
        
        guard let searchResults else {
            logger.debug("Declining to retry next page: never had a first page")
            return
        }
        
        results = .loaded(searchResults, nil)
        loadNextPageIfNeeded()
    }
}
