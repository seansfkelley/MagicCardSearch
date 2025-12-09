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
    
    var body: some View {
        let (rules, reminder) = splitReminderText(line)
        let prettyRules = buildLineText(rules)
            .font(.system(size: fontSize));
        let prettyReminder = buildLineText(reminder)
            .font(.system(size: fontSize, design: .serif))
            .italic()

        // Nit: this leaves an extra space character unconditionally. Not sure when this will ever
        // be an issue, but.
        Text("\(prettyRules) \(prettyReminder)")
    }
    
    private func buildLineText(_ text: String?) -> Text {
        guard let text = text, !text.isEmpty else { return Text("") }
        
        var pieces: [Text] = []
        let pattern = #/\{[^}]+\}/#
        var lastIterationIndex = text.startIndex
        var lastWasSymbol = false
        
        for match in text.matches(of: pattern) {
            if lastIterationIndex < match.range.lowerBound {
                let textPart = String(text[lastIterationIndex..<match.range.lowerBound])
                pieces.append(Text(textPart))
                lastWasSymbol = false
            } else if lastWasSymbol {
                pieces.append(Text(" ").font(.system(size: fontSize * 0.3)))
            }
            
            let symbol = String(text[match.range])
            if let image = renderSymbol(symbol) {
                pieces.append(Text(image).baselineOffset(fontSize * -0.15))
                lastWasSymbol = true
            }
            
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
    private func renderSymbol(_ symbol: String) -> Image? {
        let renderer = ImageRenderer(content: CircleSymbolView(symbol, size: fontSize))
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }
        return nil
    }
    
    private func splitReminderText(_ line: String) -> (String, String?) {
        if let i = line.firstIndex(of: "(") {
            let rulesText = String(line[..<i]).trimmingCharacters(in: .whitespaces)
            let reminderText = String(line[i...])
            return (rulesText, reminderText)
        } else {
            return (line, nil)
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
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Text with Symbols")
                    .font(.headline)
                OracleTextView("{T}: Add {W}{U}{B}{R}{G}.")
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Multi-line with Symbols")
                    .font(.headline)
                OracleTextView("{2}{U}{U}, {T}: Draw three cards.\nAt the beginning of your upkeep, you lose 2 life.")
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Complex Ability")
                    .font(.headline)
                OracleTextView("{X}{R}{R}: Fireball deals X damage to any target.\nFlashback {X}{2}{R}{R}")
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Mixed Symbols")
                    .font(.headline)
                OracleTextView("Tap an untapped artifact you control: Add {C}.\n{T}: Add one mana of any color.\n{3}, {T}, Sacrifice this: Draw a card.")
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("With Reminder Text")
                    .font(.headline)
                OracleTextView("Choose one —\n• Barbed Lightning deals 3 damage to target creature.\n• Barbed Lightning deals 3 damage to target player or planeswalker.\nEntwine {2} (Choose both if you pay the entwine cost.)")
            }
        }
        .padding()
    }
}
