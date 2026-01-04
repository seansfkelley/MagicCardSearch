import Foundation
import ScryfallKit

extension Card.Ruling {
    var publishedAtAsDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: publishedAt)
    }
}
