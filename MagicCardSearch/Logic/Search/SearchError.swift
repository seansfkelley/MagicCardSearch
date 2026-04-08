import SwiftUI
import ScryfallKit

enum SearchError: Error {
    case rateLimited
    case clientError
    case serverError
    case networkError
    case unknownError

    init(from error: Error) {
        self = if let scryfallKitError = error as? ScryfallKitError {
            switch scryfallKitError {
            case .scryfallError(let scryfallError):
                if (400..<500).contains(scryfallError.status) {
                    .clientError
                } else if (500..<600).contains(scryfallError.status) {
                    .serverError
                } else {
                    .unknownError
                }
            case .httpError(let status, _):
                if status == 429 {
                    .rateLimited
                } else if (400..<500).contains(status) {
                    .clientError
                } else if (500..<600).contains(status) {
                    .serverError
                } else {
                    .unknownError
                }
            default:
                .unknownError
            }
        } else {
            .networkError
        }
    }
    
    var title: String {
        switch self {
        case .rateLimited:
            "Rate Limited"
        case .clientError:
            "Search Error"
        case .serverError:
            "Scryfall is Unavailable"
        case .networkError:
            "Connection Error"
        case .unknownError:
            "Unknown Error"
        }
    }
    
    var description: String {
        switch self {
        case .rateLimited:
            "You are being rate limited by Scryfall. Slow your roll!"
        case .clientError:
            "There was a problem with your search. Please check your filters and try again."
        case .serverError:
            "Scryfall is experiencing issues. Please try again in a moment."
        case .networkError:
            "Unable to connect to Scryfall. Please check your internet connection and try again."
        case .unknownError:
            "An unknown error occured."
        }
    }
    
    var iconName: String {
        switch self {
        case .rateLimited:
            "tachometer"
        case .clientError:
            "exclamationmark.magnifyingglass"
        case .serverError:
            "server.rack"
        case .networkError:
            "wifi.exclamationmark"
        case .unknownError:
            "questionmark.circle.dashed"
        }
    }
}
