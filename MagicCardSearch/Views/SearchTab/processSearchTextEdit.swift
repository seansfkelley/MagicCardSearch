import Foundation

typealias SearchTextEdit = (filter: FilterQuery<FilterTerm>?, newText: String, newSelection: Range<String.Index>?)

func processSearchTextEdit(
    _ current: String,
    inserting edit: String,
    inRange range: Range<String.Index>,
) -> SearchTextEdit? {
    let candidate = current.replacingCharacters(in: range, with: edit)

    if candidate.allSatisfy({ $0.isWhitespace }) || candidate.isEmpty {
        return (nil, "", nil)
    }

    let editedRange = range.lowerBound..<candidate.index(range.lowerBound, offsetBy: edit.count)

    if let result = inferIntentFromAppendingOneCharacter(in: candidate, withLastEditAt: editedRange) {
        return result
    }

    if let result = quoteAdjacentBareWords(in: candidate, withLastEditAt: editedRange) {
        return result
    }

    if let result = elideExtraneousWhitespace(in: candidate, withLastEditAt: editedRange) {
        return result
    }

    return nil
}

// Only do these operations on single keystrokes at the end. This is the common case and these
// features are intended for convenience, so we don't want to fight users if they're editing
// the middle of some filter text or otherwise doing anything but the most basic of typing.
// swiftlint:disable:next cyclomatic_complexity
func inferIntentFromAppendingOneCharacter(in string: String, withLastEditAt range: Range<String.Index>) -> SearchTextEdit? {
    guard range.upperBound == string.endIndex, range.lowerBound == string.index(before: range.upperBound) else { return nil }

    // Single-quotes are generally used as apostrophes, so group it here instead of with the
    // generally-always-used-for-quoting double quote.
    if string.hasSuffix(")") || string.hasSuffix("/") || string.hasSuffix("'") {
        return if case .valid(let filter) = PartialFilterQuery.from(string) {
            filter.transformLeaves(using: FilterTerm.from).flatMap {
                switch $0 {
                // Bare name filters are very permissive, so don't consider them valid completions.
                case .term(.name): nil
                default: ($0, "", nil)
                }
            }
        } else {
            nil
        }
    }

    if string.hasSuffix(" "),
       let lexed = try? lexPartialFilterQuery(string.trimmingCharacters(in: .whitespaces)),
       lexed.count == 1,
       let term = lexed.first?.0 {
        let partial = PartialFilterTerm.from(term.content)
        if case .name(let isExact, let term) = partial.content {
            let parsedUnquoted: (PartialFilterTerm.PartialTerm.QuotingType?, String)? = switch term {
            case .bare(let content): (.doubleQuote, content)
            case .unopened(let quote, let content): (quote.opposite, content + quote.rawValue)
            default: nil
            }
            if let parsedUnquoted, let quote = parsedUnquoted.0 {
                let newText = PartialFilterTerm(
                    polarity: partial.polarity,
                    content: .name(isExact, .unclosed(quote, parsedUnquoted.1 + " ")),
                ).description
                return (nil, newText, nil)
            }
        }
    }

    if string.hasSuffix(" ") || string.hasSuffix("\"") {
        return if case .valid(let filter) = PartialFilterQuery.from(string) {
            filter.transformLeaves(using: FilterTerm.from).map { ($0, "", nil) }
        } else {
            nil
        }
    }

    return nil
}

func elideExtraneousWhitespace(in string: String, withLastEditAt range: Range<String.Index>) -> SearchTextEdit? {
    guard range.lowerBound != range.upperBound,
          string[range.lowerBound].isWhitespace,
          !string[string.index(before: range.upperBound)].isWhitespace,
          let tokens = try? lexPartialFilterQuery(string, allowingUnclosedLiterals: true) else {
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
              case .filter(_, let comparison, let term) = PartialFilterTerm.from(filterToken.content).content,
              term.incompleteContent.isEmpty,
              comparison.toComplete() != nil,
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

    return if result == string {
        nil
    } else {
        (nil, result, lower..<upper)
    }
}

func quoteAdjacentBareWords(in string: String, withLastEditAt range: Range<String.Index>) -> SearchTextEdit? {
    guard !string.isEmpty,
          !string[range].trimmingCharacters(in: .whitespaces).isEmpty,
          range.lowerBound != range.upperBound,
          range.upperBound == string.endIndex,
          let tokens = try? lexPartialFilterQuery(string) else {
        return nil
    }

    let isPrefixedByWhitespace = string[range.lowerBound].isWhitespace
    let isSuffixedByWhitespace = string[string.index(before: range.upperBound)].isWhitespace

    guard isPrefixedByWhitespace || (
        isSuffixedByWhitespace && (
            // Whitespace prefix is trivially a new word. Whitespace suffix has to make sure the
            // edit is a single separated new word.
            range.lowerBound == string.startIndex ||
            string[string.index(before: range.lowerBound)].isWhitespace
        )
    ) else {
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
        } else if code == .And {
            // continue
        } else {
            break
        }
    }

    guard let adjacentWordsStartIndex, !bareWords.isEmpty else {
        return nil
    }

    // The stock iOS keyboard prepends spaces when swipe-typing later words. This is represented by
    // the first branch here, and we don't want to put in quotes until the user has typed a second
    // word in the phrase, because otherwise we would unnecessarily quote single words all the time.
    //
    // Other keyboards will append whitespace immediately after a first word. This is represented by
    // the second branch here, and we want to eagerly put it in quotes since we have to capture the
    // whitespace both for UX clarity and because it allows the which-filter-is-the-cursor-in-now
    // behavior of autocomplete suggestions to correctly scan backwards to find the word just typed.
    guard (isPrefixedByWhitespace && bareWords.count >= 2) || isSuffixedByWhitespace else {
        return nil
    }

    let quoted = "\"" + bareWords.joined(separator: " ") + (isSuffixedByWhitespace ? " " : "")
    var result = string
    result.replaceSubrange(adjacentWordsStartIndex..<string.endIndex, with: quoted)

    let newCursor = result.index(adjacentWordsStartIndex, offsetBy: quoted.count)
    return (nil, result, newCursor..<newCursor)
}
