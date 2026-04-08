import Foundation

extension String {
    func attributed(
        in ranges: [Range<String.Index>],
        with style: (inout AttributeContainer) -> Void,
    ) -> AttributedString {
        var attributed = AttributedString(self)

        guard !ranges.isEmpty else { return attributed }

        var container = AttributeContainer()
        style(&container)

        for range in ranges {
            guard let lower = AttributedString.Index(range.lowerBound, within: attributed),
                  let upper = AttributedString.Index(range.upperBound, within: attributed) else {
                continue
            }

            attributed[lower..<upper].mergeAttributes(container)
        }

        return attributed
    }
}
