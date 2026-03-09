extension Array<FilterQuery<FilterTerm>> {
    var plaintext: String {
        map { $0.description }.joined(separator: "   ")
    }
}
