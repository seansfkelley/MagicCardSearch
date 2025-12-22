//
//  SearchResults.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-18.
//

import ScryfallKit

extension LoadableResult<SearchResults, SearchErrorState> {
    var isInitiallyLoading: Bool {
        if case .loading(let value, _) = self, value == nil {
            return true
        }
        return false
    }
    
    var isLoadingNextPage: Bool {
        if case .loading(let value, _) = self, value != nil {
            return true
        }
        return false
    }
    
    var nextPageError: SearchErrorState? {
        if case .errored(let value, let error) = self, (value?.cards.count ?? 0) > 0 {
            return error
        }
        return nil
    }
}
