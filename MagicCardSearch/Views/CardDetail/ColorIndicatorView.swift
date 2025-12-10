//
//  ColorIndicatorView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI

enum IndicatorColor: String {
    case white = "WhiteIndicatorColor"
    case blue = "BlueIndicatorColor"
    case black = "BlackIndicatorColor"
    case red = "RedIndicatorColor"
    case green = "GreenIndicatorColor"

    static func fromSymbolCode(_ code: String) -> IndicatorColor? {
        return switch code.lowercased() {
        case "w": .white
        case "u": .blue
        case "b": .black
        case "r": .red
        case "g": .green
        default: nil
        }
    }
    
    var uiColor: Color {
        return Color(self.rawValue)
    }
}

struct ColorIndicatorView: View {
    let colors: [String]
    let size: CGFloat
    
    init(colors: [String], size: CGFloat = 12) {
        self.colors = colors
        self.size = size
    }
    
    var body: some View {
        switch colors.count {
        case 0:
            EmptyView()
            
        case 1:
            if let color = IndicatorColor.fromSymbolCode(colors[0]) {
                single(color)
            } else {
                unknown()
            }
            
        case 2:
            if let left = IndicatorColor.fromSymbolCode(colors[0]),
               let right = IndicatorColor.fromSymbolCode(colors[1]) {
                double(left, right)
            } else {
                unknown()
            }
            
        default:
            unknown()
        }
    }
    
    private func single(_ color: IndicatorColor) -> some View {
        Circle()
            .fill(color.uiColor)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.5)
            )
    }
    
    private func double(_ left: IndicatorColor, _ right: IndicatorColor) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: left.uiColor, location: 0.0),
                        .init(color: left.uiColor, location: 0.5),
                        .init(color: right.uiColor, location: 0.5),
                        .init(color: right.uiColor, location: 1.0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.5)
            )
    }
    
    private func unknown() -> some View {
        ZStack {
            Circle()
                .fill(ManaColor.colorless.uiColor)
                .frame(width: size, height: size)
            
            Text("?")
                .font(.system(size: size * 0.6, weight: .bold))
                .foregroundStyle(.primary)
        }
        .overlay(
            Circle()
                .strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.5)
        )
    }
}

#Preview("Color Indicators") {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 8) {
            Text("Zero colors:")
            ColorIndicatorView(colors: [], size: 20)
        }
        
        HStack(spacing: 8) {
            Text("One color:")
            ColorIndicatorView(colors: ["U"], size: 20)
        }
        
        HStack(spacing: 8) {
            Text("Two colors:")
            ColorIndicatorView(colors: ["W", "U"], size: 20)
        }
        
        HStack(spacing: 8) {
            Text("Three colors:")
            ColorIndicatorView(colors: ["W", "U", "B"], size: 20)
        }
        
        HStack(spacing: 8) {
            Text("Each color:")
            ColorIndicatorView(colors: ["W"], size: 20)
            ColorIndicatorView(colors: ["U"], size: 20)
            ColorIndicatorView(colors: ["B"], size: 20)
            ColorIndicatorView(colors: ["R"], size: 20)
            ColorIndicatorView(colors: ["G"], size: 20)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
}
