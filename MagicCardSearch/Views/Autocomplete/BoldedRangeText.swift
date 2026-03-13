import SwiftUI

struct BoldedRangeText: View {
    let text: String
    let ranges: [Range<String.Index>]

    var body: some View {
        Text(string)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var string: AttributedString {
        var attributed = AttributedString(text)

        for range in ranges {
            guard let lower = AttributedString.Index(range.lowerBound, within: attributed),
                  let upper = AttributedString.Index(range.upperBound, within: attributed) else {
                continue
            }

            attributed[lower..<upper].font = .body.bold()
        }

        return attributed
    }
}
