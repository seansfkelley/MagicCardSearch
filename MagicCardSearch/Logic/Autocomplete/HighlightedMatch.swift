struct HighlightedMatch<T: Sendable & Hashable>: Hashable {
    let value: T
    let string: String
    lazy var highlights = computeHighlights()

    private let query: String

    init(value: T, string: String, query: String) {
        self.value = value
        self.string = string
        self.query = query
    }

    // Computes highlight ranges using a totally made-up heuristic greedy fuzzy match. The greedy
    // part just collects as many characters from the candidate in the order they appear in the
    // query, ignoring any that don't exist or are in the wrong order. We then run this twice,
    // ignoring the first character in the query, just to be robust to one-character typos at the
    // beginning of the query. Typos later are allowed to harm the quality of the match.
    //
    // Matches are scored first by total highlight count, then fewest contiguous ranges, then by
    // earliest start.
    private func computeHighlights() -> [Range<String.Index>] {
        guard !query.isEmpty, !string.isEmpty else { return [] }

        let normalizedString = string.lowercased()
        let normalizedQuery = query.lowercased()
        var best: [Range<String.Index>] = []

        // Arbitrarily run the greedy algorithm only on the first two characters so that the
        // really-obvious case where the first character is not found due to a typo still highlights
        // something. If you typo the first two characters, whatever.
        for queryStartIndex in [0, 1] {
            let partialQuery = normalizedQuery.dropFirst(queryStartIndex)

            guard !partialQuery.isEmpty else { break }

            for index in normalizedString.indices {
                if normalizedString[index] == partialQuery.first {
                    let result = greedyMatch(
                        from: index,
                        in: normalizedString,
                        matching: partialQuery,
                    )
                    if isPreferred(result, over: best) {
                        best = result
                    }
                }
            }
        }
        return best
    }

    private func greedyMatch(
        from start: String.Index,
        in normalizedString: String,
        matching normalizedQuery: Substring,
    ) -> [Range<String.Index>] {
        var ranges = [Range<String.Index>]()
        var index = start
        for char in normalizedQuery {
            guard let matchIndex = normalizedString[index...].firstIndex(of: char) else {
                continue
            }
            let nextIndex = normalizedString.index(after: matchIndex)
            if let lastHighlight = ranges.last, lastHighlight.upperBound == matchIndex {
                ranges[ranges.count - 1] = lastHighlight.lowerBound..<nextIndex
            } else {
                ranges.append(matchIndex..<nextIndex)
            }
            index = nextIndex
        }
        return ranges
    }

    private func isPreferred(_ a: [Range<String.Index>], over b: [Range<String.Index>]) -> Bool {
        func countHighlightedCharacters(_ ranges: [Range<String.Index>]) -> Int {
            ranges.reduce(0) { $0 + self.string.distance(from: $1.lowerBound, to: $1.upperBound) }
        }

        let highlightCountA = countHighlightedCharacters(a)
        let highlightCountB = countHighlightedCharacters(b)

        if highlightCountA != highlightCountB {
            return highlightCountA > highlightCountB
        }

        if a.count != b.count {
            return a.count < b.count
        }

        return (a.first?.lowerBound ?? string.endIndex) < (b.first?.lowerBound ?? string.endIndex)
    }
}
