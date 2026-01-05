import SwiftUI

@MainActor // because of ImageRenderer.
struct TextWithSymbolsBuilder {
    let fontSize: CGFloat
    let colorScheme: ColorScheme
    let scryfallCatalogs: ScryfallCatalogs

    // This can't be a view because we specifically need to return a Text for concatenation to the caller.
    func buildText(_ text: String) -> Text {
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
                    .baselineOffset(symbol.isOversized ? fontSize * -0.2 : fontSize * -0.1)
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

    private func renderSymbol(_ symbol: SymbolCode) -> Image? {
        let renderer = ImageRenderer(
            content: SymbolView(symbol, size: fontSize * 0.9)
                .environment(\.colorScheme, colorScheme)
                .environment(scryfallCatalogs),
        )
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }
        return nil
    }
}
