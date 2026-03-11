import Cache

extension Expiry {
    static func days(_ days: Int) -> Self {
        .seconds(60 * 60 * 24 * Double(days))
    }
}
