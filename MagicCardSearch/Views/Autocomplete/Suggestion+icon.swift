extension Suggestion {
    var icon: String {
        switch source {
        case .pinnedFilter: "pin.fill"
        case .historyFilter: "clock.arrow.circlepath"
        case .filterType: "line.3.horizontal.decrease"
        case .enumeration: "list.bullet"
        case .reverseEnumeration: "list.bullet"
        case .name: "rectangle.portrait"
        case .fullText: "text.rectangle"
        }
    }
}
