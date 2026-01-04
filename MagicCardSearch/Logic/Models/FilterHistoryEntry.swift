import Foundation
import SQLiteData

@Table
struct FilterHistoryEntry: Identifiable {
    let id: Int64?
    let lastUsedAt: Date
    @Column(as: SearchFilter.StableJSONRepresentation.self)
    let filter: SearchFilter

    init(filter: SearchFilter, at date: Date = .init()) {
        self.id = nil
        self.lastUsedAt = date
        self.filter = filter
    }
}
