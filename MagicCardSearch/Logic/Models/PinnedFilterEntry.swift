import Foundation
import SQLiteData

@Table
struct PinnedFilterEntry: Identifiable {
    let id: Int64?
    let pinnedAt: Date
    @Column(as: FilterQuery<FilterTerm>.StableJSONRepresentation.self)
    let filter: FilterQuery<FilterTerm>

    init(filter: FilterQuery<FilterTerm>, at date: Date = .init()) {
        self.id = nil
        self.pinnedAt = date
        self.filter = filter
    }
}
