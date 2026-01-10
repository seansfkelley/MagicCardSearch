import Foundation
import SQLiteData

@Table
struct PinnedSearchEntry: Identifiable, Equatable {
    let id: Int64?
    let pinnedAt: Date
    @Column(as: [FilterQuery<FilterTerm>].StableJSONRepresentation.self)
    let filters: [FilterQuery<FilterTerm>]

    init(filters: [FilterQuery<FilterTerm>], at date: Date = .init()) {
        self.id = nil
        self.pinnedAt = date
        self.filters = filters
    }
}
