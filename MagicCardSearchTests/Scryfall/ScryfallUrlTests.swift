import Testing
@testable import MagicCardSearch

@Suite
struct ScryfallUrlTests {
    @Test func simpleQuery() {
        let filters: [FilterQuery<FilterTerm>] = [
            .term(.basic(.positive, "c", .including, "red"))
        ]
        let url = scryfallSearchUrl(forFilters: filters, config: .defaultConfig)
        #expect(url?.absoluteString == "https://scryfall.com/search?q=c%3Ared&unique=cards&order=name&dir=auto")
    }

    @Test func simpleQueryWithPreferredPrint() {
        let filters: [FilterQuery<FilterTerm>] = [
            .term(.basic(.positive, "c", .including, "red"))
        ]
        var config = SearchConfiguration.defaultConfig
        config.preferredPrint = .oldest
        let url = scryfallSearchUrl(forFilters: filters, config: config)
        #expect(url?.absoluteString == "https://scryfall.com/search?q=prefer%3Aoldest%20c%3Ared&unique=cards&order=name&dir=auto")
    }

    // Exercises parentheses (OR group at root), double-quotes (name with space), minus sign (negated term),
    // and all non-default configuration values.
    @Test func complexQuery() {
        let filters: [FilterQuery<FilterTerm>] = [
            .or(.positive, [
                .term(.name(.positive, false, "Lightning Bolt")),
                .term(.basic(.negative, "t", .including, "instant")),
            ]),
        ]
        let config = SearchConfiguration(
            uniqueMode: .prints,
            sortField: .released,
            sortOrder: .descending,
            preferredPrint: .oldest
        )
        let url = scryfallSearchUrl(forFilters: filters, config: config)
        #expect(url?.absoluteString == "https://scryfall.com/search?q=prefer%3Aoldest%20%28%22Lightning%20Bolt%22%20or%20%2Dt%3Ainstant%29&unique=prints&order=released&dir=desc")
    }

    // Exercises encoding of slashes, backslash, plus sign, and space in a regex filter value.
    @Test func regexQuery() {
        let filters: [FilterQuery<FilterTerm>] = [
            .term(.regex(.positive, "o", .including, "url-unsafe \\w+ characters"))
        ]
        let url = scryfallSearchUrl(forFilters: filters, config: .defaultConfig)
        #expect(url?.absoluteString == "https://scryfall.com/search?q=o%3A%2Furl%2Dunsafe%20%5Cw%2B%20characters%2F&unique=cards&order=name&dir=auto")
    }

    @Test func emptyQueryReturnsNil() {
        let url = scryfallSearchUrl(forFilters: [], config: .defaultConfig)
        #expect(url == nil)
    }

    // Prefer clause should not save an otherwise-empty query from returning nil.
    @Test func emptyQueryWithNonDefaultPreferReturnsNil() {
        var config = SearchConfiguration.defaultConfig
        config.preferredPrint = .oldest
        let url = scryfallSearchUrl(forFilters: [], config: config)
        #expect(url == nil)
    }
}
