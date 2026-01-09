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
        .term(.negative, String(v.content[1...]))
    } else {
        .term(.positive, v.content)
    }
}
conjunction ::= parenthesized(d). { d }
conjunction ::= conjunction(c) And Verbatim(v). {
    let filter = if v.content.first == "-" {
        FilterQuery.term(.negative, String(v.content[1...]))
    } else {
        FilterQuery.term(.positive, v.content)
    }
    .and(.positive, [c, filter])
}
conjunction ::= conjunction(c) And parenthesized(d). {
    .and(.positive, [c, d])
}

%nonterminal_type parenthesized PartialFilterQuery
%capture_errors parenthesized end_before(CloseParen | Verbatim | Or | And).
parenthesized ::= OpenParen(l) disjunction(d) CloseParen(r). {
    .or(l.content.first == "-", [d])
}
