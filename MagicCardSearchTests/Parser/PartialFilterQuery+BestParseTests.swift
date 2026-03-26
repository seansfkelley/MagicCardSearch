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

        (
            "lightning",
            .valid(term("lightning")),
            nil
        ),
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
        (
            "/^light/",
            .valid(term("/^light/")),
            nil
        ),

        // MARK: AND / OR

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
        (
            "lightning or bolt",
            .valid(or(term("lightning"), term("bolt"))),
            nil
        ),
        // AND binds tighter than OR
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
        // Multiple parenthesized groups flatten to a single OR
        (
            "(red or blue) or (black or white)",
            .valid(or(term("red"), term("blue"), term("black"), term("white"))),
            nil
        ),
        (
            "(red or blue) creature (flying or haste)",
            .valid(and(or(term("red"), term("blue")), term("creature"), or(term("flying"), term("haste")))),
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

        (
            "-lightning",
            .valid(term(.negative, "lightning")),
            nil
        ),
        (
            "-red or blue",
            .valid(or(term(.negative, "red"), term("blue"))),
            nil
        ),
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

        // MARK: Key:Value and Operators

        // The parser treats key:value and comparison operators as opaque verbatim tokens;
        // these tests confirm the token boundary behavior and keep a couple operator styles
        // as representative examples.
        (
            "name:lightning",
            .valid(term("name:lightning")),
            nil
        ),
        (
            "power>3",
            .valid(term("power>3")),
            nil
        ),

        // MARK: Quoted Values

        // Quotes DO affect lexing, so we test both styles
        (
            "name:\"lightning bolt\"",
            .valid(term("name:\"lightning bolt\"")),
            nil
        ),
        (
            "name:'lightning bolt'",
            .valid(term("name:'lightning bolt'")),
            nil
        ),

        // MARK: Incomplete Terms

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
            "\"lightning",
            .fallback(term("\"lightning")),
            .autoterminated(term("\"lightning\""))
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

        // MARK: Complex Combinations

        (
            "-name:lightning",
            .valid(term(.negative, "name:lightning")),
            nil
        ),
        // Negation with a quoted value
        (
            "-name:\"lightning bolt\"",
            .valid(term(.negative, "name:\"lightning bolt\"")),
            nil
        ),
        // Bare negative - empty content after stripping the minus
        (
            "-",
            .valid(term(.negative, "")),
            nil
        ),
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

        // MARK: Misc

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
    ])
    func from(_ input: String, _ expected: PartialFilterQuery.BestParse, _ expectedWithAutoclose: PartialFilterQuery.BestParse?) throws {
        #expect(PartialFilterQuery.from(input) == expected)
        #expect(PartialFilterQuery.from(input, autoclosePairedDelimiters: true) == (expectedWithAutoclose ?? expected))
    }
}
