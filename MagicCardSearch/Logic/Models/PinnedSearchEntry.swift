import Foundation
import SQLiteData

@Table
struct PinnedSearchEntry: Identifiable {
    let id: Int64?
    let pinnedAt: Date
    @Column(as: SearchFilter.StableJSONRepresentation.self)
    let filters: [SearchFilter]

    init(filters: [SearchFilter], at date: Date = .init()) {
        self.id = nil
        self.pinnedAt = date
        self.filters = filters
    }
}
