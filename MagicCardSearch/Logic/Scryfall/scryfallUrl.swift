import Foundation

func scryfallSearchUrl(forFilters filters: [FilterQuery<FilterTerm>], config: SearchConfiguration? = nil) -> URL? {
    var queryString = filters.map { $0.description }.joined(separator: " ")

    guard !queryString.isEmpty else {
        return nil
    }

    // `prefer` by itself is not allowed, and doesn't really mean anything, so add it after
    // the empty check.
    if let config, let preferClause = config.preferredPrint.toFilterTerm() {
        // Scryfall will silently pick the last prefer: clause, so prepend it in case the user
        // has written one by hand in there somewhere.
        queryString = "\(preferClause.description) \(queryString)"
    }

    var components = URLComponents(string: "https://scryfall.com/search")!
    components.percentEncodedQueryItems = [
        ("q", queryString),
        config.map { ("unique", $0.uniqueMode.apiValue) },
        config.map { ("order", $0.sortField.apiValue) },
        config.map { ("dir", $0.sortOrder.apiValue) },
    ]
    .compactMap(\.self)
    .map {
        URLQueryItem(name: $0, value: $1.addingPercentEncoding(withAllowedCharacters: .alphanumerics))
    }

    return components.url
}
