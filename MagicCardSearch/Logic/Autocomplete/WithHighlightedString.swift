struct WithHighlightedString<T: Sendable & Hashable>: Hashable {
    let value: T
    let string: String
    lazy var highlights = guessHighlights()

    private let searchTerm: String

    init(value: T, string: String, searchTerm: String) {
        self.value = value
        self.string = string
        self.searchTerm = searchTerm
    }

    private func guessHighlights() -> [Range<String.Index>] {
        guard !searchTerm.isEmpty, !string.isEmpty else {
            return []
        }

        var ranges = [Range<String.Index>]()
        var stringIndex = string.startIndex

        for searchChar in searchTerm {
            var searchIndex = stringIndex
            while searchIndex < string.endIndex {
                if string[searchIndex].lowercased() == searchChar.lowercased() {
                    let nextIndex = string.index(after: searchIndex)
                    if let last = ranges.last, last.upperBound == searchIndex {
                        ranges[ranges.count - 1] = last.lowerBound..<nextIndex
                    } else {
                        ranges.append(searchIndex..<nextIndex)
                    }
                    stringIndex = nextIndex
                    break
                }
                searchIndex = string.index(after: searchIndex)
            }
        }

        return ranges
    }
}
