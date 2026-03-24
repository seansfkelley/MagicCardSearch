import SwiftUI

func didAppend(
    characterFrom characters: Set<Character>,
    to previous: String,
    toCreate current: String,
    withSelection selection: Range<String.Index>,
) -> Bool {
    guard current.count == previous.count + 1 else {
        return false
    }

    guard let lastCharacter = current.last, characters.contains(lastCharacter) else {
        return false
    }

    guard selection.upperBound == current.endIndex else {
        return false
    }

    return current.hasPrefix(previous)
}

// swiftlint:disable:next cyclomatic_complexity
func processSearchTextChange(
    _ current: String,
    inserting edit: String,
    inRange range: Range<String.Index>,
) -> (FilterQuery<FilterTerm>?, String, Range<String.Index>?)? {
    let candidate = current.replacingCharacters(in: range, with: edit)

    if candidate.allSatisfy({ $0.isWhitespace }) || candidate.isEmpty {
        return (nil, "", nil)
    }

    let editedRange = range.lowerBound..<candidate.index(range.lowerBound, offsetBy: edit.count)

    // Only do these operations on single keystrokes at the end. This is the common case and these
    // features are intended for convenience, so we don't want to fight users if they're editing
    // the middle of some filter text or otherwise doing anything but the most basic of typing.
    if editedRange.upperBound == candidate.endIndex && edit.count == 1 {
        if candidate.hasSuffix(")") || candidate.hasSuffix("/") {
            return if case .valid(let filter) = candidate.toFilter() {
                if case .term(let term) = filter, case .name = term {
                    nil
                } else {
                    (filter, "", nil)
                }
            } else {
                nil
            }
        }

        if candidate.hasSuffix(" "),
           let lexed = try? lexPartialFilterQuery(candidate.trimmingCharacters(in: .whitespaces)),
           lexed.count == 1,
           let term = lexed.first?.0 {
            let partial = PartialFilterTerm.from(term.content)
            if case .name(let isExact, let term) = partial.content {
                let parsedUnquoted: (PartialFilterTerm.PartialTerm.QuotingType?, String)? = switch term {
                case .bare(let content): (.doubleQuote, content)
                case .uninitiated(let quote, let content): (quote.opposite, content + quote.rawValue)
                default: nil
                }
                if let parsedUnquoted, let quote = parsedUnquoted.0 {
                    let newText = PartialFilterTerm(
                        polarity: partial.polarity,
                        content: .name(isExact, .unterminated(quote, parsedUnquoted.1 + " ")),
                    ).description
                    return (nil, newText, nil)
                }
            }
        }

        if candidate.hasSuffix(" ") || candidate.hasSuffix("'") || candidate.hasSuffix("\"") {
            return if case .valid(let filter) = candidate.toFilter() {
                (filter, "", nil)
            } else {
                nil
            }
        }
    }

    // If the edit was more than a character, it was a suggestion or a swipe or otherwise a bulk
    // insertion that should be handled as a unit.
    if edit.count >= 2 && edit.first!.isWhitespace && !edit.last!.isWhitespace {
        if let (newText, newSelection) = elideExtraneousWhitespace(in: candidate, withLastEditAt: editedRange),
           newText != candidate {
            return (nil, newText, newSelection)
        }

        if let (newText, newSelection) = quoteAdjacentBareWords(in: candidate, withLastEditAt: editedRange),
           newText != candidate {
            return (nil, newText, newSelection)
        }
    }

    return nil
}
