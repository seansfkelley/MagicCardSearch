import SwiftUI
import ScryfallKit

extension Card.Color {
    var indicatorUiColor: Color? {
        switch self {
        case .W: Color("WhiteIndicatorColor")
        case .U: Color("BlueIndicatorColor")
        case .B: Color("BlackIndicatorColor")
        case .R: Color("RedIndicatorColor")
        case .G: Color("GreenIndicatorColor")
        case .C: nil
        }
    }

    var name: String {
        switch self {
        case .W: "White"
        case .U: "Blue"
        case .B: "Black"
        case .R: "Red"
        case .G: "Green"
        case .C: "Colorless"
        }
    }
}
