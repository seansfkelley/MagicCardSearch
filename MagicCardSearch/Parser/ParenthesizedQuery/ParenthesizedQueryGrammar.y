%class_name ParenthesizedQueryParser

%token_type ParenthesizedQueryTokenContent

%nonterminal_type query ParenthesizedQuery
%capture_errors query.
query ::= disjunction(d). { d }

%nonterminal_type disjunction ParenthesizedQuery
%capture_errors disjunction end_after(Or).
disjunction ::= conjunction(c). { c }
disjunction ::= disjunction(d) Or conjunction(c). {
    .init(filters: d.filters + c.filters)
}

%nonterminal_type conjunction ParenthesizedQuery
%capture_errors conjunction end_after(And).
conjunction ::= Verbatim(v). {
    .init(filters: [v.range])
}
conjunction ::= parenthesized(p). { p }
conjunction ::= conjunction(c) And Verbatim(v). {
    .init(filters: c.filters + [v.range])
}
conjunction ::= conjunction(c) And parenthesized(p). {
    .init(filters: c.filters + p.filters)
}

%nonterminal_type parenthesized ParenthesizedQuery
%capture_errors parenthesized end_before(CloseParen | Verbatim | Or | And).
parenthesized ::= OpenParen(l) disjunction(d) CloseParen(r). {
    .init(filters: d.filters)
}
