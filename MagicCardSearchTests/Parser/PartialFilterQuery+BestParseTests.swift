import Testing
@testable import MagicCardSearch

private func term(_ content: String) -> PartialFilterQuery {
    .term(.init(.positive, content))
}
private func term(_ polarity: Polarity, _ content: String) -> PartialFilterQuery {
    .term(.init(polarity, content))
}

private func and(_ children: PartialFilterQuery...) -> PartialFilterQuery {
    .and(.positive, children)
}
private func and(_ polarity: Polarity, _ children: PartialFilterQuery...) -> PartialFilterQuery {
    .and(polarity, children)
}

private func or(_ children: PartialFilterQuery...) -> PartialFilterQuery {
    .or(.positive, children)
}
private func or(_ polarity: Polarity, _ children: PartialFilterQuery...) -> PartialFilterQuery {
    .or(polarity, children)
}

// Serialized: Citron is not thread-safe.
@Suite(.serialized)
struct PartialFilterQueryBestParseTests {
    @Test<[(String, PartialFilterQuery.BestParse, PartialFilterQuery.BestParse?)]>("from", arguments: [
        // MARK: Simple Queries

        // Single terms
        (
            "lightning",
            .valid(term("lightning")),
            nil
        ),

        // Quoted strings (both quote types)
        (
            "\"lightning bolt\"",
            .valid(term("\"lightning bolt\"")),
            nil
        ),
        (
            "'Serra Angel'",
            .valid(term("'Serra Angel'")),
            nil
        ),

        // Regex patterns
        (
            "/^light/",
            .valid(term("/^light/")),
            nil
        ),

        // MARK: AND Queries (Implicit with Whitespace)

        // Two terms
        (
            "lightning bolt",
            .valid(and(term("lightning"), term("bolt"))),
            nil
        ),

        // Extra whitespace gets trimmed by lexer
        (
            "  lightning   bolt    ",
            .valid(and(term("lightning"), term("bolt"))),
            nil
        ),

        // MARK: OR Queries

        // Two terms
        (
            "lightning or bolt",
            .valid(or(term("lightning"), term("bolt"))),
            nil
        ),

        // AND with OR - precedence test
        (
            "red creature or blue instant",
            .valid(or(and(term("red"), term("creature")), and(term("blue"), term("instant")))),
            nil
        ),

        // MARK: Parenthesized Queries

        // Simple parenthesized - flattened to just the term
        (
            "(lightning)",
            .valid(term("lightning")),
            nil
        ),

        // Parenthesized OR
        (
            "(red or blue)",
            .valid(or(term("red"), term("blue"))),
            nil
        ),

        // Parentheses changing precedence
        (
            "(red or blue) instant",
            .valid(and(or(term("red"), term("blue")), term("instant"))),
            nil
        ),

        // Multiple parenthesized groups - flattens to single OR
        (
            "(red or blue) or (black or white)",
            .valid(or(term("red"), term("blue"), term("black"), term("white"))),
            nil
        ),

        // Complex mixed query
        (
            "(red or blue) creature (flying or haste)",
            .valid(and(or(term("red"), term("blue")), term("creature"), or(term("flying"), term("haste")))),
            nil
        ),

        // Quoted strings in parentheses
        (
            "(\"lightning bolt\" or \"chain lightning\")",
            .valid(or(term("\"lightning bolt\""), term("\"chain lightning\""))),
            nil
        ),

        // MARK: Edge Cases

        // Empty parens - parse fails, falls back to the whole trimmed input as a term
        (
            "()",
            .fallback(term("()")),
            nil
        ),

        // Unclosed parentheses - parse fails without autoclosing, closed and parsed with it
        (
            "(red or blue",
            .fallback(term("(red or blue")),
            .autoterminated(or(term("red"), term("blue")))
        ),

        // Unmatched closing parenthesis - negative unclosed count, always falls back
        (
            "red or blue)",
            .fallback(term("red or blue)")),
            nil
        ),

        // OR at end - parse error unrelated to delimiters, same result either way
        (
            "red or",
            .fallback(term("red or")),
            nil
        ),

        // MARK: Negation

        // Simple negation
        (
            "-lightning",
            .valid(term(.negative, "lightning")),
            nil
        ),

        // Negation with OR and AND
        (
            "-red or blue",
            .valid(or(term(.negative, "red"), term("blue"))),
            nil
        ),

        // Negation in parentheses
        (
            "(-red)",
            .valid(term(.negative, "red")),
            nil
        ),
        (
            "(-red or -blue)",
            .valid(or(term(.negative, "red"), term(.negative, "blue"))),
            nil
        ),
        (
            "-(red or blue)",
            .valid(or(.negative, term("red"), term("blue"))),
            nil
        ),

        // MARK: Key:Value and Comparison Operators

        // Simple key:value
        (
            "name:lightning",
            .valid(term("name:lightning")),
            nil
        ),

        // Comparison operators (representative samples)
        (
            "power>3",
            .valid(term("power>3")),
            nil
        ),
        (
            "-color=red",
            .valid(term(.negative, "color=red")),
            nil
        ),

        // Mixed with OR and parentheses
        (
            "name:lightning or name:bolt",
            .valid(or(term("name:lightning"), term("name:bolt"))),
            nil
        ),
        (
            "(power>=2 or toughness>=3)",
            .valid(or(term("power>=2"), term("toughness>=3"))),
            nil
        ),
        (
            "((name:lightning) or (name:bolt))",
            .valid(or(term("name:lightning"), term("name:bolt"))),
            nil
        ),

        // MARK: Quoted Values

        // Double quotes
        (
            "name:\"lightning bolt\"",
            .valid(term("name:\"lightning bolt\"")),
            nil
        ),

        // Single quotes
        (
            "name:'lightning bolt'",
            .valid(term("name:'lightning bolt'")),
            nil
        ),

        // Mixed quotes with OR and parentheses
        (
            "(name:\"Serra Angel\" or name:\"Akroma\")",
            .valid(or(term("name:\"Serra Angel\""), term("name:\"Akroma\""))),
            nil
        ),

        // MARK: Incomplete Terms and Quoted Strings

        // Incomplete operators and key:value
        (
            "power>",
            .valid(term("power>")),
            nil
        ),
        (
            "name:",
            .valid(term("name:")),
            nil
        ),
        (
            "(power>) or (name:)",
            .valid(or(term("power>"), term("name:"))),
            nil
        ),

        // Unclosed double quotes consume everything including whitespace;
        // lex fails without autoclosing (falls back to trimmed input, trailing spaces stripped),
        // quote is closed with autoclosing
        (
            "name:\"lightning  ",
            .fallback(term("name:\"lightning")),
            .autoterminated(term("name:\"lightning\""))
        ),

        // Unclosed single quotes
        (
            "name:'lightning  ",
            .fallback(term("name:'lightning")),
            .autoterminated(term("name:'lightning'"))
        ),

        // Unclosed quote in parentheses - closing paren is consumed into the string;
        // with autoclosing the quote is closed and then the paren is closed too
        (
            "(name:\"lightning)",
            .fallback(term("(name:\"lightning)")),
            .autoterminated(term("name:\"lightning)\""))
        ),

        // MARK: Incomplete Regex Patterns

        // Unclosed regex - lex fails without autoclosing; with autoclosing the lexer matches
        // end-of-string (the token is treated as bare, not as an unterminated regex), so it
        // parses successfully as .valid rather than .autoterminated
        (
            "/^light",
            .fallback(term("/^light")),
            .valid(term("/^light"))
        ),

        // Multiple unclosed regex - the lexer treats it all as one token (valid without autoclosing)
        (
            "/^light /end$",
            .valid(term("/^light /end$")),
            nil
        ),

        // MARK: Nested and Incomplete Parentheses

        // Unclosed single level - autoclosing closes the paren
        (
            "(red",
            .fallback(term("(red")),
            .autoterminated(term("red"))
        ),

        // Unclosed nested - autoclosing closes one paren, both collapse to the inner term
        (
            "((red)",
            .fallback(term("((red)")),
            .autoterminated(term("red"))
        ),

        // Extra closing parentheses - negative unclosed count, always falls back
        (
            "red)",
            .fallback(term("red)")),
            nil
        ),

        // Empty unclosed parentheses - autoclosing produces () which still fails to parse
        (
            "(",
            .fallback(term("(")),
            nil
        ),
        (
            ") red",
            .fallback(term(") red")),
            nil
        ),
        (
            "red (",
            .fallback(term("red (")),
            nil
        ),

        // MARK: Complex Combinations

        // Negation with key:value and comparisons
        (
            "-name:lightning",
            .valid(term(.negative, "name:lightning")),
            nil
        ),
        (
            "-power>3",
            .valid(term(.negative, "power>3")),
            nil
        ),

        // Negation with quoted values (various quote types)
        (
            "-name:\"lightning bolt\"",
            .valid(term(.negative, "name:\"lightning bolt\"")),
            nil
        ),

        // Incomplete terms with negation
        (
            "-",
            .valid(term(.negative, "")),
            nil
        ),
        (
            "-power>",
            .valid(term(.negative, "power>")),
            nil
        ),

        // Nested parentheses with multiple features
        (
            "((name:lightning or -name:bolt) power>3)",
            .valid(and(or(term("name:lightning"), term(.negative, "name:bolt")), term("power>3"))),
            nil
        ),

        // Incomplete nested with unclosed quote; autoclosing closes both the quote and both parens
        (
            "((name:\"lightning power>3",
            .fallback(term("((name:\"lightning power>3")),
            .autoterminated(term("name:\"lightning power>3\""))
        ),

        // Unclosed single quote spanning a space; autoclosing closes the quote
        (
            "name:'bolt type:creature",
            .fallback(term("name:'bolt type:creature")),
            .autoterminated(term("name:'bolt type:creature'"))
        ),

        // Pure whitespace trims to empty
        (
            "   ",
            .empty,
            nil
        ),

        (
            "or red",
            .fallback(term("or red")),
            nil
        ),
        (
            "red or or blue",
            .fallback(term("red or or blue")),
            nil
        ),

        // MARK: Autoclosing

        // Bare unclosed double quote at start; closed to produce a quoted bare term
        (
            "\"lightning",
            .fallback(term("\"lightning")),
            .autoterminated(term("\"lightning\""))
        ),

        // Unclosed quote in key:value with a space in the value
        (
            "oracle:\"draw a card",
            .fallback(term("oracle:\"draw a card")),
            .autoterminated(term("oracle:\"draw a card\""))
        ),

        // Single term in unclosed paren; autoclosing closes the paren and flattens
        (
            "(lightning",
            .fallback(term("(lightning")),
            .autoterminated(term("lightning"))
        ),
    ])
    func from(_ input: String, _ expected: PartialFilterQuery.BestParse, _ expectedWithAutoclose: PartialFilterQuery.BestParse?) throws {
        #expect(PartialFilterQuery.from(input) == expected)
        #expect(PartialFilterQuery.from(input, autoclosePairedDelimiters: true) == (expectedWithAutoclose ?? expected))
    }
}
