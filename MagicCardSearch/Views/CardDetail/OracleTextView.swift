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
    
    init(_ oracleText: String, fontSize: CGFloat = 17) {
        self.oracleText = oracleText
        self.fontSize = fontSize
    }
    
    var body: some View {
        let lines = oracleText.split(separator: "\n", omittingEmptySubsequences: false)
        
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                LineView(line: String(line), fontSize: fontSize)
            }
        }
    }
}

private struct LineView: View {
    let line: String
    let fontSize: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let (rules, reminder) = splitReminderText(line)
        let prettyRules = buildLineText(rules)?
            .font(.system(size: fontSize))
        let prettyReminder = buildLineText(reminder)?
            .font(.system(size: fontSize, design: .serif))
            .italic()

        if let prettyRules, let prettyReminder {
            return Text("\(prettyRules) \(prettyReminder)")
        } else if let prettyRules {
            return prettyRules
        } else if let prettyReminder {
            return prettyReminder
        } else {
            return Text("")
        }
    }
    
    private func buildLineText(_ text: String?) -> Text? {
        guard let text = text, !text.isEmpty else { return nil }
        
        var pieces: [Text] = []
        let pattern = #/\{[^}]+\}/#
        var lastIterationIndex = text.startIndex
        var lastSymbol: MtgSymbol?
        
        for match in text.matches(of: pattern) {
            if lastIterationIndex < match.range.lowerBound {
                let textPart = String(text[lastIterationIndex..<match.range.lowerBound])
                pieces.append(Text(textPart))
                lastSymbol = nil
            } else if lastSymbol != nil {
                pieces.append(Text(" ").font(.system(size: fontSize * 0.3)))
            }
            
            let symbol = MtgSymbol.fromString(String(text[match.range]))
            if let image = renderSymbol(symbol) {
                pieces.append(
                    Text(image)
                        // This reduces, but does not elimiate, vertical spacing.
                        .font(.system(size: 1))
                        .baselineOffset(symbol.isOversized ? fontSize * -0.3 : fontSize * -0.15)·
                )
            }
            
            lastSymbol = symbol
            lastIterationIndex = match.range.upperBound
        }
        
        if lastIterationIndex < text.endIndex {
            let textPart = String(text[lastIterationIndex...])
            pieces.append(Text(textPart))
        }
        
        // TODO: Can this be done all at once instead of iteratively?
        return pieces.reduce(Text(""), +)
    }
    
    // TODO: Can this be done with the TextRenderer protocol or something instead of
    // rendering it to a temporary image?
    private func renderSymbol(_ symbol: MtgSymbol) -> Image? {
        let renderer = ImageRenderer(content: MtgSymbolView(symbol, size: fontSize)
            .environment(\.colorScheme, colorScheme))
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }
        return nil
    }
    
    private func splitReminderText(_ line: String) -> (String?, String?) {
        if let i = line.firstIndex(of: "(") {
            let rulesText = String(line[..<i]).trimmingCharacters(in: .whitespaces)
            let reminderText = String(line[i...])
            // Phyrexian mana reminder text, among others, can have reminder text on its own line.
            return (rulesText.isEmpty ? nil : rulesText, reminderText)
        } else {
            return (line.isEmpty ? nil : line, nil)
        }
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
        }
        .padding()
    }
}
