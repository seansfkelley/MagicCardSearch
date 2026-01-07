extension Range where Bound == String.Index {
    func shift(with string: String, by offset: Int) -> Range<String.Index> {
        let newLowerBound = string.index(lowerBound, offsetBy: offset)
        let newUpperBound = string.index(upperBound, offsetBy: offset)
        return newLowerBound..<newUpperBound
    }

    func inset(with string: String, left: Int = 0, right: Int = 0) -> Range<String.Index> {
        let newLowerBound = string.index(lowerBound, offsetBy: left)
        let newUpperBound = string.index(upperBound, offsetBy: -right)
        return newLowerBound..<newUpperBound
    }

    func length(in string: String) -> Int {
        string.distance(from: lowerBound, to: upperBound)
    }

    func clamped(within text: String) -> Range<String.Index> {
        let clampedLowerBound = Swift.max(text.startIndex, Swift.min(lowerBound, text.endIndex))
        let clampedUpperBound = Swift.max(clampedLowerBound, Swift.min(upperBound, text.endIndex))
        return clampedLowerBound..<clampedUpperBound
    }
}
