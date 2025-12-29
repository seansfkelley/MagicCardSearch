//
//  OracleTextView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-08.
//

import SwiftUI

struct OracleTextView: View {
    let oracleText: String
    let fontSize: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    init(_ oracleText: String, fontSize: CGFloat = 17) {
        self.oracleText = oracleText
        self.fontSize = fontSize
    }
    
    var body: some View {
        let lines = oracleText.split(separator: "\n", omittingEmptySubsequences: false)
        
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                buildLine(String(line)).font(.system(size: fontSize))
            }
        }
    }

    // swiftlint:disable shorthand_operator
    private func buildLine(_ text: String) -> Text {
        let reminderPattern = #/\([^)]+\)/#
        var result = Text("")
        var lastIndex = text.startIndex
        
        for match in text.matches(of: reminderPattern) {
            if lastIndex < match.range.lowerBound {
                result = result + buildTextWithSymbols(String(text[lastIndex..<match.range.lowerBound]))
            }
            result = result + buildTextWithSymbols(String(match.output))
                .font(.system(size: fontSize, design: .serif))
                .italic()
            lastIndex = match.range.upperBound
        }
        
        if lastIndex < text.endIndex {
            result = result + buildTextWithSymbols(String(text[lastIndex...]))
        }
        
        return result
    }
    // swiftlint:enable shorthand_operator

    private func buildTextWithSymbols(_ text: String) -> Text {
        guard !text.isEmpty else { return Text("") }
        
        let pattern = #/\{[^}]+\}/#
        var result = Text("")
        var lastIndex = text.startIndex
        var wasLastSymbol = false
        
        for match in text.matches(of: pattern) {
            if lastIndex < match.range.lowerBound {
                let textPart = String(text[lastIndex..<match.range.lowerBound])
                result = Text("\(result)\(Text(textPart))")
                wasLastSymbol = false
            } else if wasLastSymbol {
                result = Text("\(result)\(Text(" ").font(.system(size: fontSize * 0.3)))")
            }
            
            let symbol = SymbolCode(String(text[match.range]))
            if let image = renderSymbol(symbol) {
                let symbolText = Text(image)
                    // This reduces, but does not elimiate, vertical spacing.
                    .font(.system(size: 1))
                    // Multiplicative factors chosen empirically.
                    .baselineOffset(symbol.isOversized ?? false ? fontSize * -0.15 : fontSize * -0.05)
                result = Text("\(result)\(symbolText)")
            }
            
            wasLastSymbol = true
            lastIndex = match.range.upperBound
        }
        
        if lastIndex < text.endIndex {
            let textPart = String(text[lastIndex...])
            result = Text("\(result)\(Text(textPart))")
        }
        
        return result
    }

    // TODO: Can this be done with the TextRenderer protocol or something instead of
    // rendering it to a temporary image?
    private func renderSymbol(_ symbol: SymbolCode) -> Image? {
        let renderer = ImageRenderer(content: SymbolView(symbol, size: fontSize * 0.8)
            .environment(\.colorScheme, colorScheme))
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }
        return nil
    }
}

#Preview("Oracle Text Examples") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Simple Text")
                    .font(.headline)
                OracleTextView("Flying, vigilance")
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Text with Symbols")
                    .font(.headline)
                OracleTextView("{T}: Add {W}{U}{B}{R}{G}.")
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Multi-line with Symbols")
                    .font(.headline)
                OracleTextView("{2}{U}{U}, {T}: Draw three cards.\nAt the beginning of your upkeep, you lose 2 life.")
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Complex Ability")
                    .font(.headline)
                OracleTextView("{X}{R}{R}: Fireball deals X damage to any target.\nFlashback {X}{2}{R}{R}")
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Mixed Symbols")
                    .font(.headline)
                OracleTextView("Tap an untapped artifact you control: Add {C}.\n{T}: Add one mana of any color.\n{3}, {T}, Sacrifice this: Draw a card.")
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("With Reminder Text")
                    .font(.headline)
                OracleTextView("Choose one —\n• Barbed Lightning deals 3 damage to target creature.\n• Barbed Lightning deals 3 damage to target player or planeswalker.\nEntwine {2} (Choose both if you pay the entwine cost.)")
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Only Reminder Text")
                    .font(.headline)
                OracleTextView("({B/P} can be paid with either {B} or 2 life.)")
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Reminder Text in Middle")
                    .font(.headline)
                OracleTextView("Kicker {2}{U} (You may pay an additional {2}{U} as you cast this spell.) If this spell was kicked, draw two cards.")
            }
        }
        .padding()
    }
}
