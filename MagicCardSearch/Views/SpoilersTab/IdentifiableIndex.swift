import SwiftUI
import ScryfallKit

// TODO: Is this actually necessary, or just Claude getting weird?
/// For use with paging views that want to use a flat index, not an ID, as their binding.
struct IdentifiableIndex: Identifiable {
    let index: Int
    var id: Int { index }
}
