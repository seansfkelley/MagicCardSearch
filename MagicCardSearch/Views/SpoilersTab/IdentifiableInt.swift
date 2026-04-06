import SwiftUI
import ScryfallKit

/// For use with paging views that want to use a flat index, not an ID or object with an ID, as their binding.
struct IdentifiableInt: Identifiable, ExpressibleByIntegerLiteral {
    let value: Int
    var id: Int { value }

    init(_ value: Int) { self.value = value }
    init(integerLiteral value: Int) { self.value = value }
}
