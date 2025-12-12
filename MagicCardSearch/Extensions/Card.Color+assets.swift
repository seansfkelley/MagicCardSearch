//
//  Card.Color+Sendable.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-11.
//
import SwiftUI
import ScryfallKit

extension Card.Color {
    var basicUiColor: Color {
        switch self {
        case .W: Color("WhiteManaColor")
        case .U: Color("BlueManaColor")
        case .B: Color("BlackManaColor")
        case .R: Color("RedManaColor")
        case .G: Color("GreenManaColor")
        case .C: Color("ColorlessManaColor")
        }
    }
    
    var saturatedUiColor: Color {
        switch self {
        case .W: Color("WhiteSaturatedManaColor")
        case .U: Color("BlueSaturatedManaColor")
        case .B: Color("BlackSaturatedManaColor")
        case .R: Color("RedSaturatedManaColor")
        case .G: Color("GreenSaturatedManaColor")
        case .C: Color("ColorlessManaColor")
        }
    }
    
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
    
    var assetName: String {
        switch self {
        case .W: "w"
        case .U: "u"
        case .B: "b"
        case .R: "r"
        case .G: "g"
        case .C: "c"
        }
    }
}
