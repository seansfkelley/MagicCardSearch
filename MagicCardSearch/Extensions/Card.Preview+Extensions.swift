import ScryfallKit
import Foundation

extension Card.Preview {
    var previewedAtAsDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: previewedAt)
    }
}
