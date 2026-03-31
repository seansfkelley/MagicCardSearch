import Cache

extension Expiry {
    static func hours(_ hours: Int) -> Self {
        .seconds(60 * 60 * Double(hours))
    }

    static func days(_ days: Int) -> Self {
        .seconds(60 * 60 * 24 * Double(days))
    }
}
