//
//  Card.Color+Sendable.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-11.
//
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
}
