import Foundation
import SQLiteData

@Table
struct FilterHistoryEntry: Identifiable {
    let id: Int64?
    let lastUsedAt: Date
    @Column(as: FilterQuery<FilterTerm>.StableJSONRepresentation.self)
    let filter: FilterQuery<FilterTerm>

    init(filter: FilterQuery<FilterTerm>, at date: Date = .init()) {
        self.id = nil
        self.lastUsedAt = date
        self.filter = filter
    }
}
