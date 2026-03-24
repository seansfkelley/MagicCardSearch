import SwiftUI

func elideExtraneousWhitespace(in string: String, withLastEditAt range: Range<String.Index>) -> (String, Range<String.Index>)? {
    guard let tokens = try? lexPartialFilterQuery(string, allowingUnterminatedLiterals: true) else {
        return nil
    }

    var result = string
    var lower = range.lowerBound
    var upper = range.upperBound

    for i in stride(from: tokens.count - 1, through: 2, by: -1) {
        let (filterToken, filterCode) = tokens[i - 2]
        let (andToken, andCode) = tokens[i - 1]
        let (nameToken, nameCode) = tokens[i]

        guard filterCode == .Verbatim,
              andCode == .And,
              nameCode == .Verbatim,
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

func quoteAdjacentBareWords(in string: String, withLastEditAt range: Range<String.Index>) -> (String, Range<String.Index>)? {
    guard let tokens = try? lexPartialFilterQuery(string, allowingUnterminatedLiterals: true) else {
        return nil
    }

    var bareWords: [String] = []
    var highestEditedWordIndex: Int?
    var span: Range<String.Index>?

    for (token, code) in tokens {
        if code == .Verbatim,
           case .name(_, let term) = PartialFilterTerm.from(token.content).content,
           case .bare(let word) = term {
            if token.range.overlaps(range) || token.range.lowerBound == range.upperBound {
                highestEditedWordIndex = bareWords.count
            }
            bareWords.append(word)
            span = (span?.lowerBound ?? token.range.lowerBound)..<token.range.upperBound
        } else if code == .And, !bareWords.isEmpty {
            continue
        } else {
            if highestEditedWordIndex != nil {
                break
            }
            bareWords = []
            span = nil
        }
    }

    guard let highestEditedWordIndex,
          let span,
          bareWords.count >= 2 else {
        return nil
    }

    let quoted = "\"" + bareWords.joined(separator: " ") + "\""
    var result = string
    result.replaceSubrange(span, with: quoted)

    // Place cursor after the edited word inside the quotes.
    let cursorOffset = 1 + bareWords[0..<highestEditedWordIndex].joined(separator: " ").count + (highestEditedWordIndex > 0 ? 1 : 0) + bareWords[highestEditedWordIndex].count
    let newCursor = result.index(span.lowerBound, offsetBy: cursorOffset)
    return (result, newCursor..<newCursor)
}
