%class_name MagicCardSearchGrammar

%token_type Token

%nonterminal_type filter SearchFilter
filter ::= text(kind) Equal text(value). {
    return SearchFilter(kind, value)
}
filter ::= text(kind) Colon text(value). {
return SearchFilter(kind, value)
}
filter ::= text(kind) LessThan text(value). {
    return SearchFilter(kind, value)
}
filter ::= text(kind) LessThanOrEqual text(value). {
    return SearchFilter(kind, value)
}
filter ::= text(kind) GreaterThan text(value). {
    return SearchFilter(kind, value)
}
filter ::= text(kind) GreaterThanOrEqual text(value). {
    return SearchFilter(kind, value)
}


%nonterminal_type text String
text ::= Text(x). {
    if case .text(let text) = x {
        return text
    } else {
        preconditionFailure("lexer did not return Token.text for the Text token")
    }
}
