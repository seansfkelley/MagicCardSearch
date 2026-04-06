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
    components.queryItems = [
        URLQueryItem(name: "q", value: queryString),
        URLQueryItem(name: "unique", value: config.uniqueMode.apiValue),
        URLQueryItem(name: "order", value: config.sortField.apiValue),
        URLQueryItem(name: "dir", value: config.sortOrder.apiValue),
    ]

    return components.url
}
