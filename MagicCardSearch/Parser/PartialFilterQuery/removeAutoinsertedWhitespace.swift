import SwiftUI

func removeAutoinsertedWhitespace(_ current: String, _ selection: Range<String.Index>) -> (String, Range<String.Index>)? {
    guard let tokens = try? lexPartialFilterQuery(current, allowingUnterminatedLiterals: true) else {
        return nil
    }

    var result = current
    var lower = selection.lowerBound
    var upper = selection.upperBound

    for i in stride(from: tokens.count - 1, through: 2, by: -1) {
        let (nameToken, nameCode) = tokens[i]
        let (andToken, andCode) = tokens[i - 1]
        let (filterToken, filterCode) = tokens[i - 2]

        guard nameCode == .Verbatim,
              andCode == .And,
              filterCode == .Verbatim,
              case .filter(_, _, let term) = PartialFilterTerm.from(filterToken.content).content,
              term.incompleteContent.isEmpty,
              case .name(_, let nameTerm) = PartialFilterTerm.from(nameToken.content).content,
              !nameTerm.incompleteContent.isEmpty else {
            continue
        }

        if andToken.range.contains(lower) {
            lower = andToken.range.lowerBound
        } else if lower >= andToken.range.upperBound {
            lower = result.index(lower, offsetBy: -andToken.range.length(in: result))
        }

        // aaaaaaand, copypasta
        if andToken.range.contains(upper) {
            upper = andToken.range.lowerBound
        } else if upper >= andToken.range.upperBound {
            upper = result.index(upper, offsetBy: -andToken.range.length(in: result))
        }

        result.removeSubrange(andToken.range)
    }

    return (result, lower..<upper)
}
