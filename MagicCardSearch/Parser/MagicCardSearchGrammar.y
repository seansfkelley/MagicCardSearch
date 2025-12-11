%class_name MagicCardSearchGrammar

%token_type Token

%nonterminal_type filter SearchFilter
filter ::= filter_content(f). { .basic(f) }
filter ::= Minus filter_content(f). { .negated(f) }

%nonterminal_type filter_content SearchFilterContent
filter_content ::= Alphanumeric(k) comparison(c) QuotedLiteral(v). { .keyValue(k, c, v) }
filter_content ::= Alphanumeric(k) comparison(c) Regex(v). { .regex(k, c, v) }
filter_content ::= Alphanumeric(k) comparison(c) bare(v). { .keyValue(k, c, v) }
filter_content ::= Bang QuotedLiteral(v). { .name(v, true) }
filter_content ::= QuotedLiteral(v). { .name(v, false) }
filter_content ::= Bang bare(v). { .name(v, true) }
filter_content ::= bare(v). { .name(v, false) }

%nonterminal_type bare String
bare ::= Alphanumeric(a) Minus(m) bare(bs). { "\(a)\(m)\(bs)" }
bare ::= Alphanumeric(a) Bang(b) bare(bs). { "\(a)\(b)\(bs)" }
bare ::= Alphanumeric(a) SingleNonPairing(s) bare(bs). { "\(a)\(s)\(bs)" }
bare ::= Alphanumeric(a) UnclosedPairing(u) bare(bs). { "\(a)\(u)\(bs)" }
bare ::= Alphanumeric(a) Minus(m). { "\(a)\(m)" }
bare ::= Alphanumeric(a) Bang(b). { "\(a)\(b)" }
bare ::= Alphanumeric(a) SingleNonPairing(u). { "\(a)\(u)" }
bare ::= Alphanumeric(a) UnclosedPairing(u). { "\(a)\(u)" }
bare ::= SingleNonPairing(u) bare(bs). { "\(u)\(bs)" }
bare ::= Alphanumeric(a). { a }

%nonterminal_type comparison Comparison
comparison ::= Comparison(c). { Comparison(rawValue: c)! }
