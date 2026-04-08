import Foundation

func scryfallSearchUrl(forFilters filters: [FilterQuery<FilterTerm>], config: SearchConfiguration) -> URL? {
    var queryString = filters.map { $0.description }.joined(separator: " ")

    guard !queryString.isEmpty else {
        return nil
    }

    // `prefer` by itself is not allowed, and doesn't really mean anything, so add it after
    // the empty check.
    if let preferClause = config.preferredPrint.toStringFilter() {
        // Scryfall will silently pick the last prefer: clause, so prepend it in case the user
        // has written one by hand in there somewhere.
        queryString = "\(preferClause) \(queryString)"
    }

    var components = URLComponents(string: "https://scryfall.com/search")!
    components.percentEncodedQueryItems = [
        ("q", queryString),
        ("unique", config.uniqueMode.apiValue),
        ("order", config.sortField.apiValue),
        ("dir", config.sortOrder.apiValue),
    ].map {
        URLQueryItem(name: $0, value: $1.addingPercentEncoding(withAllowedCharacters: .alphanumerics))
    }

    return components.url
}
