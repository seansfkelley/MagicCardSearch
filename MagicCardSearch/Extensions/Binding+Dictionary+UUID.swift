import SwiftUI

extension Binding where Value == [UUID: Bool] {
    func `for`(_ id: UUID) -> Binding<Bool> {
        Binding<Bool>(
            get: { wrappedValue[id] ?? false },
            set: { wrappedValue[id] = $0 }
        )
    }
}
