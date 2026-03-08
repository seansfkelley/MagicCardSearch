extension Suggestion {
    var icon: String {
        switch source {
        case .pinnedFilter: "pin.fill"
        case .historyFilter: "clock.arrow.circlepath"
        case .filterType: "line.3.horizontal.decrease.circle"
        case .enumeration: "list.bullet.circle"
        case .reverseEnumeration: "line.3.horizontal.decrease.circle"
        case .name: "textformat.abc"
        case .fullText: "text.rectangle"
        }
    }
}
