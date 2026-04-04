import Foundation
import SwiftUI

extension AutocompleteSuggestion {
    var icon: Image {
        switch source {
        case .pinnedFilter: Image(systemName: "pin.fill")
        case .historyFilter: Image(systemName: "clock.arrow.circlepath")
        case .filterType: Image(systemName: "line.3.horizontal.decrease")
        case .enumeration: Image(systemName: "list.bullet")
        case .reverseEnumeration: Image(systemName: "list.bullet")
        case .name: Image("custom.list.bullet.rectangle.portrait")
        case .fullText: Image(systemName: "text.rectangle")
        case .regex: Image(systemName: "chevron.left.forwardslash.chevron.right")
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
