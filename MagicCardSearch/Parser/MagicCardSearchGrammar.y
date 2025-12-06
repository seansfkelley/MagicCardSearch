%class_name MagicCardSearchGrammar

%token_type Token

%nonterminal_type filter SearchFilter
filter ::= term(k) comparison(c) term(v). {
    return SearchFilter(k, c, v)
}
filter ::= term(k) comparison(c) SingleQuote terms_double_quote(v) SingleQuote. {
    return SearchFilter(k, c, v)
}
filter ::= term(k) comparison(c) DoubleQuote terms_single_quote(v) DoubleQuote. {
    return SearchFilter(k, c, v)
}
filter ::= SingleQuote terms_double_quote(v) SingleQuote. {
    return SearchFilter("name", .equal, v)
}
filter ::= DoubleQuote terms_single_quote(v) DoubleQuote. {
    return SearchFilter("name", .equal, v)
}

%nonterminal_type terms_single_quote String
terms_single_quote ::= term(t) Whitespace(w) terms_single_quote(ts). {
    return "\(t) \(ts)"
}
terms_single_quote ::= term(t) Comparison(c) terms_single_quote(ts). {
    return "\(t)\(c)\(ts)"
}
terms_single_quote ::= term(t) SingleQuote terms_single_quote(ts). {
    return "\(t)'\(ts)"
}
terms_single_quote ::= term(t). {
    return t
}

%nonterminal_type terms_double_quote String
terms_double_quote ::= term(t) Whitespace(w) terms_double_quote(ts). {
    return "\(t) \(ts)"
}
terms_double_quote ::= term(t) Comparison(c) terms_double_quote(ts). {
    return "\(t)\(c)\(ts)"
}
terms_double_quote ::= term(t) DoubleQuote terms_double_quote(ts). {
    return "\(t)\"\(ts)"
}
terms_double_quote ::= term(t). {
    return t
}

%nonterminal_type term String
term ::= Term(x). {
    if case .term(let t) = x {
        return t
    } else {
        preconditionFailure("lexer did not return Token.term for the Term token")
    }
}

%nonterminal_type comparison Comparison
comparison ::= Including. {
    .including
}
comparison ::= Equal. {
    .equal
}
comparison ::= NotEqual. {
    .notEqual
}
comparison ::= LessThan. {
    .lessThan
}
comparison ::= LessThanOrEqual. {
    .lessThanOrEqual
}
comparison ::= GreaterThan. {
    .greaterThan
}
comparison ::= GreaterThanOrEqual. {
    .greaterThanOrEqual
}
