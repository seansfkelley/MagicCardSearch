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
        baseAttributes = [
            .font: font,
            .foregroundColor: UIColor.label,
        ]

        do {
            var attrs = baseAttributes
            attrs[.font] = UIFont.systemFont(ofSize: fontSize * 0.3)
            attrs[.isSpacer] = true
            spacerAttributes = attrs
        }

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
        let textView = SymbolCopyableTextView()
        textView.isEditable = false
        textView.isSelectable = false
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
                lastIndex = match.range.lowerBound
            }

            if lastIndex != text.startIndex {
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
                // By basing it off of the given attributes, we get proper fallback behavior when
                // the symbol is e.g. in reminder text and therefore should be italicized.
                var symbolAttributes = attributes
                symbolAttributes[.symbolText] = symbol.rawValue
                segment.addAttributes(
                    symbolAttributes,
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
    static let isSpacer = NSAttributedString.Key("isSpacer")
}

// Reimplements the SwiftUI-style Copy/Share... button for a UITextView. I don't know if there's
// a simpler way to bridge my desire for visually lightweight long-press-copy/share and elegant
// fallback from images/format -> just format -> plain text. UITextView doesn't seem to support the
// format and SwiftUI's Text doesn't seem to support the latter.
private class SymbolCopyableTextView: UITextView, @preconcurrency UIEditMenuInteractionDelegate {
    private var editMenuInteraction: UIEditMenuInteraction?

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)

        let interaction = UIEditMenuInteraction(delegate: self)
        addInteraction(interaction)
        editMenuInteraction = interaction

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        addGestureRecognizer(longPress)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        let config = UIEditMenuConfiguration(identifier: nil, sourcePoint: recognizer.location(in: self))
        editMenuInteraction?.presentEditMenu(with: config)
    }

    func editMenuInteraction(
        _ interaction: UIEditMenuInteraction,
        menuFor configuration: UIEditMenuConfiguration,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        let fullRange = NSRange(location: 0, length: textStorage.length)
        return UIMenu(children: [
            UIAction(title: "Copy") { [weak self] _ in
                self?.copyAttributedRange(fullRange)
            },
            UIAction(title: "Share\u{2026}") { [weak self] _ in
                guard let self else { return }
                let rich = self.richWithoutImages(from: self.textStorage.attributedSubstring(from: fullRange))
                let activityVC = UIActivityViewController(activityItems: [rich], applicationActivities: nil)
                activityVC.popoverPresentationController?.sourceView = self
                self.nearestViewController?.present(activityVC, animated: true)
            },
        ])
    }

    private var nearestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }

    // Strips private attributes and spacer runs; leaves NSTextAttachment as-is.
    private func richWithImages(from attributed: NSAttributedString) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length), options: []) { attrs, attrRange, _ in
            if let isSpacer = attrs[.isSpacer] as? Bool, isSpacer {
                // do nothing
            } else if let strRange = Range(attrRange, in: attributed.string) {
                var cleanAttrs = attrs
                cleanAttrs.removeValue(forKey: .symbolText)
                result.append(NSAttributedString(string: String(attributed.string[strRange]), attributes: cleanAttrs))
            }
        }
        return result
    }

    // Replaces symbol image attachments with their {X} text equivalents, retaining font/color.
    private func richWithoutImages(from attributed: NSAttributedString) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length), options: []) { attrs, attrRange, _ in
            if let symbolText = attrs[.symbolText] as? String {
                var textAttrs = attrs
                textAttrs.removeValue(forKey: .attachment)
                textAttrs.removeValue(forKey: .symbolText)
                result.append(NSAttributedString(string: symbolText, attributes: textAttrs))
            } else if let isSpacer = attrs[.isSpacer] as? Bool, isSpacer {
                // do nothing; it is useless without images
            } else if let strRange = Range(attrRange, in: attributed.string) {
                result.append(NSAttributedString(string: String(attributed.string[strRange]), attributes: attrs))
            }
        }
        return result
    }

    private func copyAttributedRange(_ range: NSRange) {
        let selected = textStorage.attributedSubstring(from: range)
        let richWithImages = richWithImages(from: selected)
        let richWithoutImages = richWithoutImages(from: selected)

        var pasteboardItem: [String: Any] = ["public.utf8-plain-text": richWithoutImages.string]

        if let rtfdData = try? richWithImages.data(
            from: NSRange(location: 0, length: richWithImages.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd],
        ) {
            pasteboardItem["com.apple.flat-rtfd"] = rtfdData
        }

        if let rtfData = try? richWithoutImages.data(
            from: NSRange(location: 0, length: richWithoutImages.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf],
        ) {
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
