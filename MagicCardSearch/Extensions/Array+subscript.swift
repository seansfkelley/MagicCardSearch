extension Array where Indices.Iterator.Element == Index {
    subscript(safe index: Index) -> Iterator.Element? {
        if index >= startIndex && index < endIndex {
            self[index]
        } else {
            nil
        }
    }
}
