import FuzzyMatch

struct DeferredMatchHighlight<T: Sendable> {
    let value: T
    let string: String
    lazy var highlights: [Range<String.Index>] = matcher.highlight(string, against: query) ?? []

    private let matcher: FuzzyMatcher
    private let query: FuzzyQuery

    init(value: T, string: String, matcher: FuzzyMatcher, query: FuzzyQuery) {
        self.value = value
        self.string = string
        self.matcher = matcher
        self.query = query
    }
}

