extension String {
    var range: Range<String.Index> { startIndex..<endIndex }
    var endIndexRange: Range<String.Index> { endIndex..<endIndex }
}
