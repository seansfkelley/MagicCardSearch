%class_name ParenthesizedQueryParser

%token_type ParenthesizedQueryTokenContent

%nonterminal_type query ParenthesizedQuery
query ::= disjunction(d). { d }

%nonterminal_type disjunction ParenthesizedQuery
disjunction ::= conjunction(c). { c }
disjunction ::= disjunction(d) Or conjunction(c). {
    .init(range: d.range.lowerBound..<c.range.upperBound, filters: d.filters + c.filters)
}
// Permit incomplete expressins.
//disjunction ::= disjunction(d) Or(o). {
//    .init(filters: d.filters, range: d.range.lowerBound..<o.range.upperBound)
//}

%nonterminal_type conjunction ParenthesizedQuery
conjunction ::= term(t). { t }
conjunction ::= conjunction(c) And term(t). {
    .init(range: c.range.lowerBound..<t.range.upperBound, filters: c.filters + t.filters)
}
// Permit incomplete expressions.
//conjunction ::= conjunction(c) And(a). {
//    .init(filters: c.filters, range: c.range.lowerBound..<a.range.upperBound)
//}

%nonterminal_type term ParenthesizedQuery
term ::= Verbatim(v). {
    .init(range: v.range, filters: [v.range])
}
term ::= OpenParen(l) disjunction(q) CloseParen(r). {
    .init(range: l.range.lowerBound..<r.range.upperBound, filters: q.filters)
}
// Permit incomplete expressions.
//term ::= OpenParen(l) disjunction(q). {
//    .init(filters: q.filters, range: l.range.lowerBound..<q.range.upperBound)
//}
