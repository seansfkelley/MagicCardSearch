import SwiftUI

/// A view that understands MTG's {}-based syntax and renders inline symbols, while also supporting
/// rich selection and copy interactions that feel native and preserve formatting where possible.
struct SymbolizedTextView: UIViewRepresentable {
    // This used to be a VStack of Texts, but that didn't support visible cursor highlighting,
    // cross-paragraph highlighting (at least, not while also supporting different line/paragraph
    // spacing) or including formatting/symbols in the copied text.

    private let text: String
    private let baseAttributes: [NSAttributedString.Key: Any]
    private let parentheticalAttributes: [NSAttributedString.Key: Any]?
    private let spacerAttributes: [NSAttributedString.Key: Any]
    private let symbolSize: CGFloat
    private let symbolCenterLine: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ScryfallCatalogs.self) private var scryfallCatalogs

    init(_ text: String, fontSize: CGFloat = 17, italicizeParentheticals: Bool = true) {
        self.text = text

        let font = UIFont.systemFont(ofSize: fontSize)
        baseAttributes = [.font: font, .foregroundColor: UIColor.label]
        spacerAttributes = [.font: UIFont.systemFont(ofSize: fontSize * 0.3)]

        if italicizeParentheticals,
           let descriptor = font.fontDescriptor.withDesign(.serif)?.withSymbolicTraits(.traitItalic) {
            var attrs = baseAttributes
            attrs[.font] = UIFont(descriptor: descriptor, size: fontSize)
            parentheticalAttributes = attrs
        } else {
            parentheticalAttributes = nil
        }

        // Below numbers chosen empirically. I tried to define something based on `font`'s various
        // metrics like xHeight, but nothing looked good without pixel-pushing so I gave up all
        // pretense and just picked some numbers.
        symbolSize = fontSize * 0.9
        symbolCenterLine = fontSize * 0.35
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
        var result: NSMutableAttributedString

        if let parentheticalAttributes {
            let draft = NSMutableAttributedString()
            let reminderPattern = #/\([^)]+\)/#
            var lastIndex = text.startIndex

            for match in text.matches(of: reminderPattern) {
                if lastIndex < match.range.lowerBound {
                    draft.append(buildSegment(String(text[lastIndex..<match.range.lowerBound]), withAttributes: baseAttributes))
                }
                draft.append(buildSegment(String(match.output), withAttributes: parentheticalAttributes))
                lastIndex = match.range.upperBound
            }

            if lastIndex < text.endIndex {
                draft.append(buildSegment(String(text[lastIndex...]), withAttributes: baseAttributes))
            }

            result = draft
        } else {
            result = buildSegment(text, withAttributes: baseAttributes)
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 8
        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))

        return result
    }

    private func buildSegment(_ text: String, withAttributes attributes: [NSAttributedString.Key: Any]) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        let symbolPattern = #/\{[^}]+\}/#
        var lastIndex = text.startIndex

        for match in text.matches(of: symbolPattern) {
            if lastIndex < match.range.lowerBound {
                result.append(NSAttributedString(string: String(text[lastIndex..<match.range.lowerBound]), attributes: attributes))
            } else if lastIndex != text.startIndex {
                // Spacers between symbols for when there is no intervening text to separate them.
                result.append(NSAttributedString(string: " ", attributes: spacerAttributes))
            }

            let symbol = SymbolCode(String(text[match.range]))
            if let image = renderSymbol(symbol) {
                let symbolAttachment = NSTextAttachment()
                // Do not use the `image:` initializer; that sets the bounds and ignores the
                // override below.
                symbolAttachment.image = image
                // Oversize symbols should stay oversize, so measure the actual size of the image
                // and bound it to center itself vertically.
                symbolAttachment.bounds = CGRect(
                    x: 0,
                    y: symbolCenterLine - (image.size.height / 2),
                    width: image.size.width,
                    height: image.size.height,
                )
                let segment = NSMutableAttributedString(attachment: symbolAttachment)
                segment.addAttributes(
                    [.symbolText: symbol.rawValue],
                    range: NSRange(location: 0, length: segment.length),
                )
                result.append(segment)
            } else {
                result.append(NSAttributedString(string: String(text[match.range]), attributes: attributes))
            }

            lastIndex = match.range.upperBound
        }

        if lastIndex < text.endIndex {
            result.append(NSAttributedString(string: String(text[lastIndex...]), attributes: attributes))
        }

        return result
    }

    private func renderSymbol(_ symbol: SymbolCode) -> UIImage? {
        let renderer = ImageRenderer(
            content: SymbolView(symbol, size: symbolSize)
                .environment(\.colorScheme, colorScheme)
                .environment(scryfallCatalogs)
        )
        renderer.scale = UITraitCollection.current.displayScale
        return if let image = renderer.uiImage { image } else { nil }
    }
}

private extension NSAttributedString.Key {
    static let symbolText = NSAttributedString.Key("symbolText")
}

private class SelectableTextView: UITextView {
    // Reimplement the iOS-editable-text behavior whereby 2 taps _immediately_ selects the word
    // under the cursor (without the gesture-diambiguation delay) and 3 does same for paragraphs.
    // I would like this to also have 4 select the entire range, but at the time of writing this
    // function is only being called with odd numbers of taps (?!), possibly because whatever is
    // handling double taps is taking all even-numbered events. Removing the super call changes
    // nothing.
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let touch = touches.first, touch.tapCount >= 3 else { return }
        let location = touch.location(in: self)
        guard let position = closestPosition(to: location) else { return }
        let charOffset = offset(from: beginningOfDocument, to: position)
        let nsText = text as NSString
        var range = nsText.paragraphRange(for: NSRange(location: charOffset, length: 0))
        if range.length > 0,
           nsText.substring(with: NSRange(location: NSMaxRange(range) - 1, length: 1)) == "\n" {
            range.length -= 1
        }
        selectedRange = range
    }

    override func copy(_ sender: Any?) {
        let range = selectedRange
        guard range.length > 0 else { return }
        let selected = textStorage.attributedSubstring(from: range)

        // Rich version with symbol images intact (for RTFD targets like Notes/Pages/Mail).
        // Strip only the private .symbolText attribute; leave NSTextAttachment as-is.
        let richWithImages = NSMutableAttributedString(attributedString: selected)
        richWithImages.removeAttribute(.symbolText, range: NSRange(location: 0, length: richWithImages.length))

        // Text-only version: replace attachments with their symbol text, retaining font/color.
        let richWithoutImages = NSMutableAttributedString()
        selected.enumerateAttributes(in: NSRange(location: 0, length: selected.length), options: []) { attrs, attrRange, _ in
            if let symbolText = attrs[.symbolText] as? String {
                var textAttrs = attrs
                textAttrs.removeValue(forKey: .attachment)
                textAttrs.removeValue(forKey: .symbolText)
                richWithoutImages.append(NSAttributedString(string: symbolText, attributes: textAttrs))
            } else if let strRange = Range(attrRange, in: selected.string) {
                richWithoutImages.append(NSAttributedString(string: String(selected.string[strRange]), attributes: attrs))
            }
        }

        var pasteboardItem: [String: Any] = ["public.utf8-plain-text": richWithoutImages.string]

        let imagesRange = NSRange(location: 0, length: richWithImages.length)
        if let rtfdData = try? richWithImages.data(from: imagesRange, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]) {
            pasteboardItem["com.apple.flat-rtfd"] = rtfdData
        }

        let noImagesRange = NSRange(location: 0, length: richWithoutImages.length)
        if let rtfData = try? richWithoutImages.data(from: noImagesRange, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            pasteboardItem["public.rtf"] = rtfData
        }

        UIPasteboard.general.items = [pasteboardItem]
    }
}

#Preview("Oracle Text Examples") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Simple Text")
                    .font(.headline)
                SymbolizedTextView("Flying, vigilance")
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Text with Symbols")
                    .font(.headline)
                SymbolizedTextView("{T}: Add {W}{U}{B}{R}{G}.")
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Multi-line with Symbols")
                    .font(.headline)
                SymbolizedTextView("{2}{U}{U}, {T}: Draw three cards.\nAt the beginning of your upkeep, you lose 2 life.")
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Complex Ability")
                    .font(.headline)
                SymbolizedTextView("{X}{R}{R}: Fireball deals X damage to any target.\nFlashback {X}{2}{R}{R}")
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Mixed Symbols")
                    .font(.headline)
                SymbolizedTextView("Tap an untapped artifact you control: Add {C}.\n{T}: Add one mana of any color.\n{3}, {T}, Sacrifice this: Draw a card.")
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("With Reminder Text")
                    .font(.headline)
                SymbolizedTextView("Choose one —\n• Barbed Lightning deals 3 damage to target creature.\n• Barbed Lightning deals 3 damage to target player or planeswalker.\nEntwine {2} (Choose both if you pay the entwine cost.)")
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Only Reminder Text")
                    .font(.headline)
                SymbolizedTextView("({B/P} can be paid with either {B} or 2 life.)")
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Reminder Text in Middle")
                    .font(.headline)
                SymbolizedTextView("Kicker {2}{U} (You may pay an additional {2}{U} as you cast this spell.) If this spell was kicked, draw two cards.")
            }
        }
        .padding()
    }
    .environment(ScryfallCatalogs())
}
