import Logging

private let logger = Logger(label: "PlausibleFilterRanges")

struct PlausibleFilterRanges {
    // Note that these are not guaranteed to be all filters; on parse error we stop trying and
    // return only those that we have definitely identified so far.
    let ranges: [Range<String.Index>]
    
    static func from(_ input: String) -> PlausibleFilterRanges {
        let trimmedInput = input.trimmingCharacters(in: .whitespaces)
        let prefixOffset = input.prefixMatch(of: /\s*/)?.count ?? 0
        
        do {
            // The grammar is simple enough that we can rely on the lexer directly without having to
            // have the proper parser resolve things for us. Nice.
            var ranges = (try lexParenthesizedQuery(trimmedInput, allowingUnterminatedLiterals: true))
                .compactMap { token, code in
                    if code == .Verbatim || code == .Or {
                        // `Or` can be the beginning of a well-formed filter, like `oracle`, or a
                        // bare word, so include it.
                        return token.range.offset(with: input, by: prefixOffset)
                    } else if code == .OpenParen {
                        let nextIndex = input.index(token.range.upperBound, offsetBy: prefixOffset)
                        if nextIndex == input.endIndex || input[nextIndex] == " " {
                            // You can add a filter after an open paren, only only _right_ after and
                            // only if there's whitespace after it, rather than another paren or an
                            // existing filter range.
                            return (token.range.upperBound..<token.range.upperBound).offset(with: input, by: prefixOffset)
                        }
                    }

                    return nil
                }

            if let match = input.firstMatch(of: /^\s+\S/) {
                ranges.insert(match.range.lowerBound..<input.index(match.range.upperBound, offsetBy: -2), at: 0)
            }

            if let match = input.firstMatch(of: /\S\s+$/) {
                ranges.append(input.index(match.range.lowerBound, offsetBy: 2)..<match.range.upperBound)
            }

            // TODO: Add intermediate whitespace candidates. Anywhere outside of a literal where
            // two or more whitespace appear in sequence has at least a zero-width range of
            // whitespace where a filter can be safetly syntactically added, and we should suggest
            // something when the cursor is there.

            let coalescedRanges = ranges.reduce(into: [Range<String.Index>]()) { result, range in
                if let last = result.last, last.upperBound == range.lowerBound {
                    result.removeLast()
                    result.append(last.lowerBound..<range.upperBound)
                } else {
                    result.append(range)
                }
            }

            return .init(ranges: coalescedRanges)
        } catch {
            logger.error("Lexer errored, which should not happen", metadata: [
                "error": "\(error)",
            ])
            return .init(ranges: [])
        }
    }
}
