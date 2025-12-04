%class_name MagicCardSearchGrammar

%token_type Token

%nonterminal_type filter SearchFilter
filter ::= set_filter(f). { return f }
filter ::= manavalue_filter(f). { return f }
filter ::= name_filter(f). { return f }

%nonterminal_type set_filter SearchFilter
set_filter ::= Set string_comparison(c) text(s). {
    return .set(c, s)
}

%nonterminal_type manavalue_filter SearchFilter
manavalue_filter ::= ManaValue comparison(c) text(s). {
    return .manaValue(c, s)
}

%nonterminal_type name_filter SearchFilter
name_filter ::= text(n). {
    // TODO: Split on whitespace I guess?
    return .name([n])
}

%nonterminal_type string_comparison StringComparison
string_comparison ::= Equal. {
    return .equal
}
string_comparison ::= NotEqual. {
    return .notEqual
}

%nonterminal_type comparison Comparison
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

%nonterminal_type text String
text ::= Text(x). {
    if case .text(let text) = x {
        return text
    } else {
        preconditionFailure("lexer did not return Token.text for the Text token")
    }
}
