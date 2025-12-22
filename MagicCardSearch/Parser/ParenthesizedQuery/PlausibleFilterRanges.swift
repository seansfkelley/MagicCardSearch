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
            return .init(
                ranges: (try lexParenthesizedQuery(trimmedInput, allowingUnterminatedLiterals: true))
                    .filter { $0.1 == .Verbatim }
                    .map { $0.0.range.offset(with: input, by: prefixOffset) }
            )
        } catch {
            logger.error("Lexer errored, which should not happen", metadata: [
                "error": "\(error)",
            ])
            return .init(ranges: [])
        }
    }
}
