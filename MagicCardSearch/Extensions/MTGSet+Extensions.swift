import Foundation
import ScryfallKit

// Instantiating these in a loop can be very slow!
nonisolated(unsafe) private let setReleaseDateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    return formatter
}()

extension MTGSet {
    var releasedAtAsDate: Date? {
        guard let releasedAt else { return nil }
        return setReleaseDateFormatter.date(from: releasedAt)
    }
}
