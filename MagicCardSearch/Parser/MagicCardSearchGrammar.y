%class_name MagicCardSearchGrammar

%token_type Token

%nonterminal_type filter SearchFilter
filter ::= filter_content(f). { .basic(f) }
filter ::= Minus filter_content(f). { .negated(f) }

%nonterminal_type filter_content SearchFilterContent
filter_content ::= Alphanumeric(k) comparison(c) Alphanumeric(v). { .keyValue(k, c, v) }
filter_content ::= Alphanumeric(k) comparison(c) QuotedLiteral(v). { .keyValue(k, c, v) }
filter_content ::= Alphanumeric(k) comparison(c) Regex(v). { .keyValue(k, c, v) }
filter_content ::= QuotedLiteral(v). { .name(v) }
filter_content ::= bare(v). { .name(v) }

%nonterminal_type bare String
bare ::= Alphanumeric(t) Minus(m) bare(ts). { "\(t)\(m)\(ts)" }
bare ::= Alphanumeric(t) Unmatched(u) bare(ts). { "\(t)\(u)\(ts)" }
bare ::= Alphanumeric(t). { t }

%nonterminal_type comparison Comparison
comparison ::= Comparison(c). { Comparison(rawValue: c)! }
