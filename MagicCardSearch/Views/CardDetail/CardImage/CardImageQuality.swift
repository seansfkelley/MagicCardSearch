import ScryfallKit

enum CardImageQuality {
    case small
    case normal
    case large

    func uri(from: Card.ImageUris?) -> String? {
        switch self {
        case .small: from?.small
        case .normal: from?.normal
        case .large: from?.large
        }
    }

    static func bestQualityUri(from uris: Card.ImageUris?) -> String? {
        uris?.large ?? uris?.normal ?? uris?.small
    }
}
