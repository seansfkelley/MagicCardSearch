//
//  SearchErrorState.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI

enum SearchErrorState {
    case clientError // 4xx errors
    case serverError // 5xx errors
    case other
    
    init(from error: Error) {
        if let searchError = error as? SearchError,
           case .httpError(let statusCode) = searchError {
            if (400..<500).contains(statusCode) {
                self = .clientError
            } else if (500..<600).contains(statusCode) {
                self = .serverError
            } else {
                self = .other
            }
        } else {
            self = .other
        }
    }
    
    var title: String {
        switch self {
        case .clientError:
            return "Search Error"
        case .serverError:
            return "Scryfall is Unavailable"
        case .other:
            return "Connection Error"
        }
    }
    
    var description: String {
        switch self {
        case .clientError:
            return "There was a problem with your search. Please check your filters and try again."
        case .serverError:
            return "Scryfall is experiencing issues. Please try again in a moment."
        case .other:
            return "Unable to connect to Scryfall. Please check your internet connection and try again."
        }
    }
    
    var iconName: String {
        switch self {
        case .clientError:
            return "exclamationmark.triangle"
        case .serverError:
            return "server.rack"
        case .other:
            return "wifi.slash"
        }
    }
}
