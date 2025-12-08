//
//  ColorIndicatorView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI

struct ColorIndicatorView: View {
    let colors: [String]
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(colors, id: \.self) { color in
                Circle()
                    .fill(colorForIdentifier(color))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.5)
                    )
            }
        }
    }
    
    private func colorForIdentifier(_ identifier: String) -> Color {
        switch identifier.uppercased() {
        case "W":
            return Color(red: 0.98, green: 0.95, blue: 0.82)
        case "U":
            return Color(red: 0.0, green: 0.45, blue: 0.81)
        case "B":
            return Color(red: 0.13, green: 0.13, blue: 0.13)
        case "R":
            return Color(red: 0.9, green: 0.27, blue: 0.22)
        case "G":
            return Color(red: 0.0, green: 0.58, blue: 0.33)
        default:
            return Color.gray
        }
    }
}
