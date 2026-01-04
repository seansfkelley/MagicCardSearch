extension Range where Bound == Int {
    func toStringIndices(in string: String) -> Range<String.Index>? {
        let lower = string.index(string.startIndex, offsetBy: lowerBound, limitedBy: string.endIndex)
        let upper = string.index(string.startIndex, offsetBy: upperBound, limitedBy: string.endIndex)
        return if let lower, let upper {
            lower..<upper
        } else {
            nil
        }
    }
}
