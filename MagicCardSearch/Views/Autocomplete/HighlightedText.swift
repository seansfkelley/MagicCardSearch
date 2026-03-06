import SwiftUI

struct HighlightedText: View {
    let text: String
    let highlightRanges: [Range<String.Index>]

    init(text: String, highlightRanges: [Range<String.Index>]) {
        self.text = text
        self.highlightRanges = highlightRanges
    }

    init(text: String, highlightRange: Range<String.Index>?) {
        self.text = text
        self.highlightRanges = highlightRange.map { [$0] } ?? []
    }

    var body: some View {
        if highlightRanges.isEmpty {
            Text(text)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        } else {
            Text(buildAttributedString())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func buildAttributedString() -> AttributedString {
        var attributedString = AttributedString(text)

        for range in highlightRanges {
            let startOffset = text.distance(from: text.startIndex, to: range.lowerBound)
            let endOffset = text.distance(from: text.startIndex, to: range.upperBound)

            let attrStart = attributedString.index(
                attributedString.startIndex,
                offsetByCharacters: startOffset
            )
            let attrEnd = attributedString.index(
                attributedString.startIndex,
                offsetByCharacters: endOffset
            )

            attributedString[attrStart..<attrEnd].font = .body.bold()
        }

        return attributedString
    }
}
