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
    guard range.upperBound == string.endIndex,
          let tokens = try? lexPartialFilterQuery(string) else {
        return nil
    }

    var bareWords: [String] = []
    var adjacentWordsStartIndex: String.Index?

    for (token, code) in tokens.reversed() {
        if code == .Verbatim,
           case .name(_, let term) = PartialFilterTerm.from(token.content).content,
           case .bare(let word) = term {
            bareWords.insert(word, at: 0)
            adjacentWordsStartIndex = token.range.lowerBound
        } else if code != .And || bareWords.isEmpty {
            break
        }
    }

    guard let adjacentWordsStartIndex, bareWords.count >= 2 else {
        return nil
    }

    let quoted = "\"" + bareWords.joined(separator: " ") + "\""
    var result = string
    result.replaceSubrange(adjacentWordsStartIndex..<string.endIndex, with: quoted)

    let newCursor = result.index(adjacentWordsStartIndex, offsetBy: quoted.count - 1)
    return (result, newCursor..<newCursor)
}
