struct SetCode: RawRepresentable, Equatable, Hashable, Sendable, Codable, CodingKeyRepresentable, CustomStringConvertible {
    let rawValue: String

    init(_ set: String) {
        self.rawValue = set.trimmingCharacters(in: .whitespaces).uppercased()
    }

    init?(rawValue: String) {
        self.init(rawValue)
    }

    var description: String {
        "Set[\(rawValue)]"
    }
}
