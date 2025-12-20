%class_name ParenthesizedQueryParser

%token_type ParenthesizedQueryTokenContent

%nonterminal_type query ParenthesizedQuery
query ::= disjunction(d). { d }

%nonterminal_type disjunction ParenthesizedQuery
disjunction ::= conjunction(c). { c }
disjunction ::= disjunction(d) Or conjunction(c). {
    .init(range: d.range.lowerBound..<c.range.upperBound, filters: d.filters + c.filters)
}

%nonterminal_type conjunction ParenthesizedQuery
conjunction ::= Verbatim(v). {
    .init(range: v.range, filters: [v.range])
}
conjunction ::= parenthesized(p). { p }
conjunction ::= conjunction(c) And Verbatim(v). {
    .init(range: c.range.lowerBound..<v.range.upperBound, filters: c.filters + [v.range])
}
conjunction ::= conjunction(c) And parenthesized(p). {
    .init(range: c.range.lowerBound..<p.range.upperBound, filters: c.filters + p.filters)
}

%nonterminal_type parenthesized ParenthesizedQuery
%capture_errors parenthesized end_after(CloseParen).
parenthesized ::= OpenParen(l) disjunction(q) CloseParen(r). {
    .init(range: l.range.lowerBound..<r.range.upperBound, filters: q.filters)
}
