%class_name ParenthesizedQueryParser

%token_type ParenthesizedQueryTokenContent

%nonterminal_type query ParenthesizedQuery
query ::= disjunction(d). { d }

%nonterminal_type disjunction ParenthesizedQuery
disjunction ::= conjunction(c). { c }
disjunction ::= disjunction(d) Whitespace Or Whitespace conjunction(c). {
    .init(filters: d.filters + c.filters, range: d.range.lowerBound..<c.range.upperBound)
}

%nonterminal_type conjunction ParenthesizedQuery
conjunction ::= term(t). { t }
conjunction ::= conjunction(c) Whitespace term(t). {
    .init(filters: c.filters + t.filters, range: c.range.lowerBound..<t.range.upperBound)
}

%nonterminal_type term ParenthesizedQuery
term ::= literal(l). {
    .init(filters: [l.range], range: l.range)
}
term ::= OpenParen(l) disjunction(q) CloseParen(r). {
    .init(filters: q.filters, range: l.range.lowerBound..<r.range.upperBound)
}
term ::= OpenParen(l) Whitespace disjunction(q) CloseParen(r). {
    .init(filters: q.filters, range: l.range.lowerBound..<r.range.upperBound)
}
term ::= OpenParen(l) disjunction(q) Whitespace CloseParen(r). {
    .init(filters: q.filters, range: l.range.lowerBound..<r.range.upperBound)
}
term ::= OpenParen(l) Whitespace disjunction(q) Whitespace CloseParen(r). {
    .init(filters: q.filters, range: l.range.lowerBound..<r.range.upperBound)
}

%nonterminal_type literal ParenthesizedQueryTokenContent
literal ::= Verbatim(v). { v }
literal ::= Verbatim(v1) Verbatim(v2). {
    .init(content: "\(v1)\(v2)", range: v1.range.lowerBound..<v1.range.upperBound)
}
