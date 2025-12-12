//
//  SearchErrorState.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI
import ScryfallKit

enum SearchErrorState {
    case clientError // 4xx errors (excluding 404 from searches)
    case serverError // 5xx errors
    case networkError // Connection issues
    
    init(from error: Error) {
        // Check for ScryfallError first
        if let scryfallKitError = error as? ScryfallKitError,
           case .scryfallError(let scryfallError) = scryfallKitError {
            let statusCode = scryfallError.status
            if (400..<500).contains(statusCode) {
                self = .clientError
            } else if (500..<600).contains(statusCode) {
                self = .serverError
            } else {
                self = .networkError
            }
        } else if let searchError = error as? SearchError {
            switch searchError {
            case .httpError(let statusCode):
                if (400..<500).contains(statusCode) {
                    self = .clientError
                } else if (500..<600).contains(statusCode) {
                    self = .serverError
                } else {
                    self = .networkError
                }
            case .invalidURL, .invalidResponse:
                self = .clientError
            }
        } else {
            self = .networkError
        }
    }
    
    var title: String {
        switch self {
        case .clientError:
            return "Search Error"
        case .serverError:
            return "Scryfall is Unavailable"
        case .networkError:
            return "Connection Error"
        }
    }
    
    var description: String {
        switch self {
        case .clientError:
            return "There was a problem with your search. Please check your filters and try again."
        case .serverError:
            return "Scryfall is experiencing issues. Please try again in a moment."
        case .networkError:
            return "Unable to connect to Scryfall. Please check your internet connection and try again."
        }
    }
    
    var iconName: String {
        switch self {
        case .clientError:
            return "exclamationmark.triangle"
        case .serverError:
            return "server.rack"
        case .networkError:
            return "wifi.slash"
        }
    }
}
