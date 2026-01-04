import Foundation
import SQLiteData

@Table
struct BlobEntry {
    let key: String
    let value: Data
    let insertedAt: Date

    init(key: String, value: Data, at date: Date = .init()) {
        self.key = key
        self.value = value
        self.insertedAt = date
    }
}
