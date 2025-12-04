%class_name MagicCardSearchGrammar

%token_type Token

%nonterminal_type filter SearchFilter
filter ::= kind(k) Equal text(value). {
    return SearchFilter(k, .equal, value)
}
filter ::= kind(k) Colon text(value). {
return SearchFilter(k, .colon, value)
}
filter ::= kind(k) LessThan text(value). {
    return SearchFilter(k, .lessThan, value)
}
filter ::= kind(k) LessThanOrEqual text(value). {
    return SearchFilter(k, .lessThanOrEqual, value)
}
filter ::= kind(k) GreaterThan text(value). {
    return SearchFilter(k, .greaterThan, value)
}
filter ::= kind(k) GreaterThanOrEqual text(value). {
    return SearchFilter(k, .greaterThanOrEqual, value)
}
filter ::= text(name). {
    return SearchFilter(.name, .nameContains, name)
}
filter ::= Quote text(name) Quote. {
    return SearchFilter(.name, .nameContains, name)
}

%nonterminal_type kind FilterKind
kind ::= Set. {
    return .set
}
kind ::= ManaValue. {
    return .manaValue
}


%nonterminal_type text String
text ::= Text(x). {
    if case .text(let text) = x {
        return text
    } else {
        preconditionFailure("lexer did not return Token.text for the Text token")
    }
}
