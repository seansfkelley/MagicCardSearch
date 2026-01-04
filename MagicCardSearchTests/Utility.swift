func stringIndexRange(_ from: Int, _ to: Int) -> Range<String.Index> {
    return
        String.Index.init(encodedOffset: from)
        ..<
        String.Index.init(encodedOffset: to)
}

func stringIndexRange(_ range: Range<Int>) -> Range<String.Index> {
    return
        String.Index.init(encodedOffset: range.lowerBound)
        ..<
        String.Index.init(encodedOffset: range.upperBound)
}
