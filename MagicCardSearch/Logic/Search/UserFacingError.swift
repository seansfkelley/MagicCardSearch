import SwiftUI
import ScryfallKit

enum UserFacingError: Error {
    case rateLimited
    case clientError
    case serverError
    case networkError
    case unknownError

    init(from error: Error) {
        self = if let scryfallKitError = error as? ScryfallKitError {
            switch scryfallKitError {
            case .scryfallError(let scryfallError):
                Self.fromHttpStatus(scryfallError.status)
            case .httpError(let status, _):
                Self.fromHttpStatus(status)
            default:
                .unknownError
            }
        } else if let urlError = error as? URLError {
            // Best-effort list of the codes that we use in the application.
            switch urlError.code {
            case .notConnectedToInternet: .networkError
            case .badServerResponse, .cannotDecodeContentData, .cannotParseResponse: .serverError
            default: .unknownError
            }
        } else {
            .networkError
        }
    }

    private static func fromHttpStatus(_ status: Int) -> UserFacingError {
        if status == 429 {
            .rateLimited
        } else if (400..<500).contains(status) {
            .clientError
        } else if (500..<600).contains(status) {
            .serverError
        } else {
            .unknownError
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
