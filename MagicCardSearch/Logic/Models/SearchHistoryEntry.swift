import Foundation
import SQLiteData

@Table
struct SearchHistoryEntry: Identifiable {
    let id: Int64?
    let lastUsedAt: Date
    @Column(as: [FilterQuery<FilterTerm>].StableJSONRepresentation.self)
    let filters: [FilterQuery<FilterTerm>]

    init(filters: [FilterQuery<FilterTerm>], at date: Date = .init()) {
        self.id = nil
        self.lastUsedAt = date
        self.filters = filters
    }
}
