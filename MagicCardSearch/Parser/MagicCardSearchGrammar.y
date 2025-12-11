%class_name MagicCardSearchGrammar

%token_type Token

%nonterminal_type filter SearchFilter
filter ::= filter_content(f). { .basic(f) }
filter ::= Minus filter_content(f). { .negated(f) }

%nonterminal_type filter_content SearchFilterContent
filter_content ::= term(k) comparison(c) term(v). { .keyValue(k, c, v) }
filter_content ::= term(k) comparison(c) SingleQuote single_quotable_term(v) SingleQuote. { .keyValue(k, c, v) }
filter_content ::= term(k) comparison(c) DoubleQuote double_quotable_term(v) DoubleQuote. { .keyValue(k, c, v) }
filter_content ::= SingleQuote single_quotable_term(v) SingleQuote. { .name(v) }
filter_content ::= DoubleQuote double_quotable_term(v) DoubleQuote. { .name(v) }
filter_content ::= bare_term(v). { .name(v) }

%nonterminal_type double_quotable_term String
double_quotable_term ::= term(t) Whitespace(w) double_quotable_term(ts). { "\(t) \(ts)" }
double_quotable_term ::= term(t) Comparison(c) double_quotable_term(ts). { "\(t)\(c)\(ts)" }
double_quotable_term ::= term(t) SingleQuote double_quotable_term(ts). { "\(t)'\(ts)" }
double_quotable_term ::= term(t) Minus double_quotable_term(ts). { "\(t)-\(ts)" }
double_quotable_term ::= term(t). { t }

%nonterminal_type single_quotable_term String
single_quotable_term ::= term(t) Whitespace(w) single_quotable_term(ts). { "\(t) \(ts)" }
single_quotable_term ::= term(t) Comparison(c) single_quotable_term(ts). { "\(t)\(c)\(ts)" }
single_quotable_term ::= term(t) DoubleQuote single_quotable_term(ts). { "\(t)\"\(ts)" }
single_quotable_term ::= term(t) Minus single_quotable_term(ts). { "\(t)-\(ts)" }
single_quotable_term ::= term(t). { t }

%nonterminal_type bare_term String
bare_term ::= term(t) Whitespace(w) bare_term(ts). { "\(t) \(ts)" }
bare_term ::= term(t) SingleQuote bare_term(ts). { "\(t)'\(ts)" }
bare_term ::= term(t) DoubleQuote bare_term(ts). { "\(t)\"\(ts)" }
bare_term ::= term(t) Comparison(c) bare_term(ts). { "\(t)\(c)\(ts)" }
bare_term ::= term(t) Minus bare_term(ts). { "\(t)-\(ts)" }
bare_term ::= term(t). { t }

%nonterminal_type term String
term ::= Term(x). {
    if case .term(let t) = x {
        return t
    } else {
        preconditionFailure("lexer did not return Token.term for the Term token")
    }
}

%nonterminal_type comparison Comparison
comparison ::= Including. { .including }
comparison ::= Equal. { .equal }
comparison ::= NotEqual. { .notEqual }
comparison ::= LessThan. { .lessThan }
comparison ::= LessThanOrEqual. { .lessThanOrEqual }
comparison ::= GreaterThan. { .greaterThan }
comparison ::= GreaterThanOrEqual. { .greaterThanOrEqual }
