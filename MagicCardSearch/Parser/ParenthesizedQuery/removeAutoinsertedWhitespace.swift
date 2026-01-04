import SwiftUI

func removeAutoinsertedWhitespace(_ current: String) -> String? {
    removeAutoinsertedWhitespace(current, nil)?.0
}

func removeAutoinsertedWhitespace(_ current: String, _ selection: TextSelection?) -> (String, TextSelection?)? {
    guard let tokens = try? lexParenthesizedQuery(current, allowingUnterminatedLiterals: true) else {
        return nil
    }

    var result = current
    var range: Range<String.Index>? = switch selection?.indices {
    case .selection(let range): range
    default: nil
    }

    for i in stride(from: tokens.count - 1, through: 2, by: -1) {
        let (nameToken, nameCode) = tokens[i]
        let (andToken, andCode) = tokens[i - 1]
        let (filterToken, filterCode) = tokens[i - 2]

        guard nameCode == .Verbatim,
              andCode == .And,
              filterCode == .Verbatim,
              case .filter(_, _, let term) = PartialSearchFilter.from(filterToken.content).content,
              term.incompleteContent.isEmpty,
              case .name(_, let nameTerm) = PartialSearchFilter.from(nameToken.content).content,
              !nameTerm.incompleteContent.isEmpty else {
            continue
        }

        if var lower = range?.lowerBound, var upper = range?.upperBound {
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

            range = lower..<upper
        }

        result.removeSubrange(andToken.range)
    }

    return (result, range.map(TextSelection.init(range:)))
}
