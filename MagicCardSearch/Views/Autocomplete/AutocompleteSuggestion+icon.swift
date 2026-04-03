import Foundation

extension AutocompleteSuggestion {
    var icon: String {
        switch source {
        case .pinnedFilter: "pin.fill"
        case .historyFilter: "clock.arrow.circlepath"
        case .filterType: "line.3.horizontal.decrease"
        case .enumeration: "list.bullet"
        case .reverseEnumeration: "list.bullet"
        case .name: "custom.list.bullet.rectangle.portrait"
        case .fullText: "text.rectangle"
        case .regex: "chevron.left.forwardslash.chevron.right"
        }
    }

    static let defaultIconFontSize = 18.0

    // I would prefer to just scale it, but I don't know how to say "body size * factor" in SwiftUI.
    // I don't want to use imageScale, and scaleEffect doesn't affect the nearby layout correctly.
    var iconFontSize: CGFloat {
        switch source {
        case .regex: 15.0
        default: Self.defaultIconFontSize
        }
    }
}
