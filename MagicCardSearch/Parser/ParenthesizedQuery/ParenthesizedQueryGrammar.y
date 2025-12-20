%class_name ParenthesizedQueryParser

%token_type ParenthesizedQueryTokenContent

%nonterminal_type query ParenthesizedQuery
query ::= disjunction(d). { d }

%nonterminal_type disjunction ParenthesizedQuery
disjunction ::= conjunction(c). { c }
disjunction ::= disjunction(d) Or conjunction(c). {
    .init(filters: d.filters + c.filters)
}

%nonterminal_type conjunction ParenthesizedQuery
conjunction ::= Verbatim(range). {
    .init(filters: [range])
}
conjunction ::= parenthesized(p). { p }
conjunction ::= conjunction(c) And Verbatim(range). {
    .init(filters: c.filters + [range])
}
conjunction ::= conjunction(c) And parenthesized(p). {
    .init(filters: c.filters + p.filters)
}

%nonterminal_type parenthesized ParenthesizedQuery
%capture_errors parenthesized end_after(CloseParen).
parenthesized ::= OpenParen(l) disjunction(q) CloseParen(r). {
    .init(filters: q.filters)
}
