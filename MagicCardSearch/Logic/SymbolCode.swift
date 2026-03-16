struct SymbolCode: RawRepresentable, Equatable, Hashable, Sendable, Codable, CodingKeyRepresentable, CustomStringConvertible {
    let rawValue: String

    init(_ symbol: String) {
        let trimmed = symbol.trimmingCharacters(in: .whitespaces).uppercased()
        self.rawValue =
            trimmed.hasPrefix("{") && trimmed.hasSuffix("}")
            ? trimmed
            : "{\(trimmed)}"
    }

    init?(rawValue: String) {
        self.init(rawValue)
    }

    var description: String {
        "Symbol\(rawValue)"
    }

    var isOversized: Bool {
        // TODO: Consult the symbology, but at the time of writing, this is 100% correct.
        rawValue.contains("/")
    }
}
