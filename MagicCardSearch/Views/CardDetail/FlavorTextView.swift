//
//  FlavorTextView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-28.
//
import SwiftUI

struct FlavorTextView: View {
    let flavorText: String
    let fontSize: CGFloat
    
    init(_ flavorText: String, fontSize: CGFloat = 17) {
        self.flavorText = flavorText
        self.fontSize = fontSize
    }
    
    var body: some View {
        let lines = flavorText.components(separatedBy: "\n")
        
        VStack(alignment: .leading, spacing: 8) {
            ForEach(lines, id: \.self) { line in
                if !line.isEmpty {
                    FlavorLineView(line: line, fontSize: fontSize)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct FlavorLineView: View {
    let line: String
    let fontSize: CGFloat
    
    var body: some View {
        buildFlavorText(line)
    }

    // swiftlint:disable shorthand_operator
    private func buildFlavorText(_ text: String) -> Text {
        let pattern = #/\*([^*]+)\*/#
        var result = Text("")
        var lastIndex = text.startIndex
        
        for match in text.matches(of: pattern) {
            if lastIndex < match.range.lowerBound {
                result = result + Text(text[lastIndex..<match.range.lowerBound]).italic()
            }
            result = result + Text(match.output.1)
            lastIndex = match.range.upperBound
        }
        
        if lastIndex < text.endIndex {
            result = result + Text(text[lastIndex...]).italic()
        }
        
        return result
            .font(.system(size: fontSize, design: .serif))
    }
    // swiftlint:enable shorthand_operator
}

#Preview("Flavor Text Examples") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Simple Italic Text")
                    .font(.headline)
                FlavorTextView("The shadows whispered secrets of ages past.")
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Text with Regular Words")
                    .font(.headline)
                FlavorTextView("The *planeswalker* vanished into the *Blind Eternities*.")
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Multi-line Flavor Text")
                    .font(.headline)
                FlavorTextView("\"In the heart of *Ravnica*, power flows like water.\"\n—Niv-Mizzet")
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Multiple Regular Sections")
                    .font(.headline)
                FlavorTextView("The *Gatewatch* stood against *Nicol Bolas* at the *Meditation Realm*.")
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Mixed Content")
                    .font(.headline)
                FlavorTextView("\"I've seen the fall of *Theros* and the rise of countless heroes.\"\n\"Yet nothing prepared me for *Elesh Norn*.\"")
            }
        }
        .padding()
    }
}
