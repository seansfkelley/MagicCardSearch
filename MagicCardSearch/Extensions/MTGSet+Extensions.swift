import Foundation
import ScryfallKit

extension MTGSet {
    var releasedAtAsDate: Date? {
        guard let releasedAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: releasedAt)
    }
}
