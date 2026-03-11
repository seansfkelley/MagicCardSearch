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
func maybeAutoUpdateSearchText(
    previous: String,
    current: String,
    selection: Range<String.Index>,
) -> (FilterQuery<FilterTerm>?, String, Range<String.Index>?)? {
    if didAppend(characterFrom: [" "], to: previous, toCreate: current, withSelection: selection) {
        if current.allSatisfy({ $0.isWhitespace }) {
            return (nil, "", nil)
        }

        if (try? /^-?\(/.prefixMatch(in: previous)) == nil {
            // Note that we use `previous` so that the additional space doesn't interfere
            // with our interpretation of what the filter was like before it potentially
            // became a multi-word name filter. This also means that we have to add the
            // space back when we update the search text.
            let partial = PartialFilterTerm.from(previous)
            if case .name(let isExact, let term) = partial.content {
                let parsed: (PartialFilterTerm.PartialTerm.QuotingType?, String)? = switch term {
                case .bare(let content): (.doubleQuote, content)
                case .uninitiated(let quote, let content): (quote.opposite, content + quote.rawValue)
                default: nil
                }
                if let parsed, let quote = parsed.0 {
                    let newText = PartialFilterTerm(
                        polarity: partial.polarity,
                        content: .name(isExact, .unterminated(quote, parsed.1 + " ")),
                    ).description
                    return (nil, newText, nil)
                }
            }
        }
    }

    if didAppend(characterFrom: [" ", "'", "\"", ")", "/"], to: previous, toCreate: current, withSelection: selection) {
        if case .valid(let filter) = current.toFilter() {
            return (filter, "", nil)
        }
        return nil
    }

    if let (newText, newSelection) = removeAutoinsertedWhitespace(current, selection),
       newText != current {
        return (nil, newText, newSelection)
    }

    return nil
}
