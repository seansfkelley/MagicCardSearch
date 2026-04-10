import SwiftUI

private extension NSAttributedString.Key {
    static let symbolText = NSAttributedString.Key("symbolText")
}

private class SelectableTextView: UITextView {
    override func copy(_ sender: Any?) {
        let range = selectedRange
        guard range.length > 0 else { return }
        let selected = textStorage.attributedSubstring(from: range)

        // Rich version with symbol images intact (for RTFD targets like Notes/Pages/Mail).
        // Strip only the private .symbolText attribute; leave NSTextAttachment as-is.
        let richWithImages = NSMutableAttributedString(attributedString: selected)
        richWithImages.removeAttribute(.symbolText, range: NSRange(location: 0, length: richWithImages.length))

        // Text-only version: replace attachments with their symbol text, retaining font/color.
        let richNoImages = NSMutableAttributedString()
        selected.enumerateAttributes(in: NSRange(location: 0, length: selected.length), options: []) { attrs, attrRange, _ in
            if let symbolText = attrs[.symbolText] as? String {
                var textAttrs = attrs
                textAttrs.removeValue(forKey: .attachment)
                textAttrs.removeValue(forKey: .symbolText)
                richNoImages.append(NSAttributedString(string: symbolText, attributes: textAttrs))
            } else if let strRange = Range(attrRange, in: selected.string) {
                richNoImages.append(NSAttributedString(string: String(selected.string[strRange]), attributes: attrs))
            }
        }

        var item: [String: Any] = ["public.utf8-plain-text": richNoImages.string]
        let imagesRange = NSRange(location: 0, length: richWithImages.length)
        let noImagesRange = NSRange(location: 0, length: richNoImages.length)
        if let rtfdData = try? richWithImages.data(from: imagesRange, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]) {
            item["com.apple.flat-rtfd"] = rtfdData
        }
        if let rtfData = try? richNoImages.data(from: noImagesRange, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            item["public.rtf"] = rtfData
        }
        UIPasteboard.general.items = [item]
    }
}

struct OracleTextView: UIViewRepresentable {
    let oracleText: String
    let fontSize: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ScryfallCatalogs.self) private var scryfallCatalogs

    init(_ oracleText: String, fontSize: CGFloat = 17) {
        self.oracleText = oracleText
        self.fontSize = fontSize
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = SelectableTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.attributedText = buildAttributedString()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }

    private func buildAttributedString() -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: fontSize)
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label,
        ]

        let result = NSMutableAttributedString()
        let lines = oracleText.split(separator: "\n", omittingEmptySubsequences: false)

        for (index, line) in lines.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n", attributes: baseAttributes))
            }
            result.append(buildLine(String(line), baseAttributes: baseAttributes))
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 8
        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))

        return result
    }

    private func buildLine(_ text: String, baseAttributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let reminderPattern = #/\([^)]+\)/#
        var lastIndex = text.startIndex

        for match in text.matches(of: reminderPattern) {
            if lastIndex < match.range.lowerBound {
                result.append(buildSegment(String(text[lastIndex..<match.range.lowerBound]), attributes: baseAttributes))
            }
            result.append(buildSegment(String(match.output), attributes: serifItalicAttributes(from: baseAttributes)))
            lastIndex = match.range.upperBound
        }

        if lastIndex < text.endIndex {
            result.append(buildSegment(String(text[lastIndex...]), attributes: baseAttributes))
        }

        return result
    }

    private func serifItalicAttributes(from base: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        var attrs = base
        let baseFont = UIFont.systemFont(ofSize: fontSize)
        if let serifDescriptor = baseFont.fontDescriptor.withDesign(.serif),
           let italicDescriptor = serifDescriptor.withSymbolicTraits(.traitItalic) {
            attrs[.font] = UIFont(descriptor: italicDescriptor, size: fontSize)
        }
        return attrs
    }

    private func buildSegment(_ text: String, attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let pattern = #/\{[^}]+\}/#
        var lastIndex = text.startIndex
        var wasLastSymbol = false

        for match in text.matches(of: pattern) {
            if lastIndex < match.range.lowerBound {
                result.append(NSAttributedString(string: String(text[lastIndex..<match.range.lowerBound]), attributes: attributes))
                wasLastSymbol = false
            } else if wasLastSymbol {
                var smallAttrs = attributes
                smallAttrs[.font] = UIFont.systemFont(ofSize: fontSize * 0.3)
                result.append(NSAttributedString(string: " ", attributes: smallAttrs))
            }

            let symbol = SymbolCode(String(text[match.range]))
            if let (image, symbolSize) = renderSymbol(symbol) {
                let capHeight = (attributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: fontSize)).capHeight
                let attachment = NSTextAttachment(image: image)
                attachment.bounds = CGRect(x: 0, y: (capHeight - symbolSize) / 2, width: symbolSize, height: symbolSize)
                let attachStr = NSMutableAttributedString(attachment: attachment)
                var attachAttrs: [NSAttributedString.Key: Any] = [.symbolText: symbol.rawValue]
                if let font = attributes[.font] {
                    attachAttrs[.font] = font
                }
                attachStr.addAttributes(attachAttrs, range: NSRange(location: 0, length: attachStr.length))
                result.append(attachStr)
            } else {
                result.append(NSAttributedString(string: String(text[match.range]), attributes: attributes))
            }

            wasLastSymbol = true
            lastIndex = match.range.upperBound
        }

        if lastIndex < text.endIndex {
            result.append(NSAttributedString(string: String(text[lastIndex...]), attributes: attributes))
        }

        return result
    }

    private func renderSymbol(_ symbol: SymbolCode) -> (UIImage, CGFloat)? {
        let baseSize = fontSize * 0.9
        let targetSize = symbol.isOversized ? baseSize * 1.25 : baseSize
        let renderer = ImageRenderer(
            content: SymbolView(symbol, size: baseSize)
                .environment(\.colorScheme, colorScheme)
                .environment(scryfallCatalogs)
        )
        renderer.scale = UITraitCollection.current.displayScale
        guard let image = renderer.uiImage else { return nil }
        return (image, targetSize)
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
    .environment(ScryfallCatalogs())
}
