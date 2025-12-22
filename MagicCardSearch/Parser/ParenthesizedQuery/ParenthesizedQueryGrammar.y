%class_name ParenthesizedQueryParser

%token_type ParenthesizedQueryTokenContent

%nonterminal_type query ParenthesizedDisjunction
%capture_errors query.
query ::= disjunction(d). { d }

%nonterminal_type disjunction ParenthesizedDisjunction
%capture_errors disjunction end_after(Or).
disjunction ::= conjunction(c). {
    .init(false, [c])
}
disjunction ::= disjunction(d) Or conjunction(c). {
    .init(false, d.clauses + [c])
}

%nonterminal_type conjunction ParenthesizedConjunction
%capture_errors conjunction end_after(And).
conjunction ::= Verbatim(v). {
    .init([.filter(v.content)])
}
conjunction ::= parenthesized(d). {
    .init([.disjunction(d)])
}
conjunction ::= conjunction(c) And Verbatim(v). {
    .init(c.clauses + [.filter(v.content)])
}
conjunction ::= conjunction(c) And parenthesized(d). {
    .init(c.clauses + [.disjunction(d)])
}

%nonterminal_type parenthesized ParenthesizedDisjunction
%capture_errors parenthesized end_before(CloseParen | Verbatim | Or | And).
parenthesized ::= OpenParen(l) disjunction(d) CloseParen(r). {
    .init(l.content.first == "-", d.clauses)
}
