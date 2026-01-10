%class_name PartialFilterQueryParser

%token_type PartialFilterQueryTokenContent

%nonterminal_type query PartialFilterQuery
query ::= disjunction(d). { d }

%nonterminal_type disjunction PartialFilterQuery
disjunction ::= conjunction(c). { c }
disjunction ::= disjunction(d) Or conjunction(c). {
    .or(.positive, [d, c])
}

%nonterminal_type conjunction PartialFilterQuery
conjunction ::= Verbatim(v). {
    if v.content.first == "-" {
        .term(
            .init(
                .negative,
                String(v.content.suffix(from: v.content.index(after: v.content.startIndex))),
            ),
        )
    } else {
        .term(.init(.positive, v.content))
    }
}
conjunction ::= parenthesized(d). { d }
conjunction ::= conjunction(c) And Verbatim(v). {
    let string: PolarityString = if v.content.first == "-" {
        .init(
            .negative,
            String(v.content.suffix(from: v.content.index(after: v.content.startIndex))),
        )
    } else {
        .init(.positive, v.content)
    }
    return .and(.positive, [c, .term(string)])
}
conjunction ::= conjunction(c) And parenthesized(d). {
    .and(.positive, [c, d])
}

%nonterminal_type parenthesized PartialFilterQuery
parenthesized ::= OpenParen(l) disjunction(d) CloseParen(r). {
    .or(l.content.first == "-" ? .negative : .positive, [d])
}
