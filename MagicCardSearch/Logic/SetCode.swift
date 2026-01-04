struct SetCode: Equatable, Hashable, Sendable, Codable, CustomStringConvertible {
    let normalized: String

    init(_ set: String) {
        self.normalized = set.trimmingCharacters(in: .whitespaces).uppercased()
    }

    var description: String {
        "Set[\(normalized)]"
    }
}
