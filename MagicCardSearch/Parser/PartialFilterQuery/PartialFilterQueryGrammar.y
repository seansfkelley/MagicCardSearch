%class_name PartialFilterQueryParser

%token_type PartialFilterQueryTokenContent

%nonterminal_type query PartialFilterQuery
%capture_errors query.
query ::= disjunction(d). { d }

%nonterminal_type disjunction PartialFilterQuery
%capture_errors disjunction end_after(Or).
disjunction ::= conjunction(c). { c }
disjunction ::= disjunction(d) Or conjunction(c). {
    .or(.positive, [d, c])
}

%nonterminal_type conjunction PartialFilterQuery
%capture_errors conjunction end_after(And).
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
%capture_errors parenthesized end_before(CloseParen | Verbatim | Or | And).
parenthesized ::= OpenParen(l) disjunction(d) CloseParen(r). {
    .or(l.content.first == "-" ? .negative : .positive, [d])
}
