import Testing
@testable import MagicCardSearch

private func term(_ content: String) -> FilterQuery<PolarityString> {
    .term(.init(.positive, content))
}
private func term(_ polarity: Polarity, _ content: String) -> FilterQuery<PolarityString> {
    .term(.init(polarity, content))
}

private func and(_ children: FilterQuery<PolarityString>...) -> FilterQuery<PolarityString> {
    .and(.positive, children)
}
private func and(_ polarity: Polarity, _ children: FilterQuery<PolarityString>...) -> FilterQuery<PolarityString> {
    .and(polarity, children)
}

private func or(_ children: FilterQuery<PolarityString>...) -> FilterQuery<PolarityString> {
    .or(.positive, children)
}
private func or(_ polarity: Polarity, _ children: FilterQuery<PolarityString>...) -> FilterQuery<PolarityString> {
    .or(polarity, children)
}

@Suite("FilterQuery")
struct FilterQueryTests {
    // MARK: - description

    @Test<[(FilterQuery<PolarityString>, String)]>("description", arguments: [
        // Single terms
        (term("foo"), "foo"),
        (term(.negative, "foo"), "-foo"),
        // AND is always parenthesized at root
        (and(term("a"), term("b")), "(a b)"),
        (and(.negative, term("a"), term("b")), "-(a b)"),
        (and(term("a")), "(a)"),
        // OR is always parenthesized at root
        (or(term("a"), term("b")), "(a or b)"),
        (or(.negative, term("a"), term("b")), "-(a or b)"),
        // Nested: OR inside AND gets extra parentheses; AND inside OR does not
        (and(or(term("a"), term("b")), term("c")), "((a or b) c)"),
        (or(and(term("a"), term("b")), term("c")), "(a b or c)"),
    ])
    func description(input: FilterQuery<PolarityString>, expected: String) {
        #expect(input.description == expected)
    }

    // MARK: - flattened

    @Test<[(FilterQuery<PolarityString>, FilterQuery<PolarityString>)]>("flattened", arguments: [
        // Term is unchanged
        (
            term("a"),
            term("a"),
        ),
        // AND with no nesting is unchanged
        (
            and(term("a"), term("b")),
            and(term("a"), term("b")),
        ),
        // Single-element AND: unwraps and keeps term
        (
            and(term("a")),
            term("a"),
        ),
        // Single-element AND: unwraps and negates term
        (
            and(.negative, term("a")),
            term(.negative, "a"),
        ),
        // Positive inner AND is unwrapped into the outer AND
        (
            and(and(term("a"), term("b")), term("c")),
            and(term("a"), term("b"), term("c")),
        ),
        // Negative inner AND is not unwrapped
        (
            and(and(.negative, term("a"), term("b")), term("c")),
            and(and(.negative, term("a"), term("b")), term("c")),
        ),
        // Single-element OR: unwraps and keeps term
        (
            or(term("a")),
            term("a"),
        ),
        // Single-element OR: unwraps and negates term
        (
            or(.negative, term("a")),
            term(.negative, "a"),
        ),
        // Positive inner OR is unwrapped into the outer OR
        (
            or(or(term("a"), term("b")), term("c")),
            or(term("a"), term("b"), term("c")),
        ),
        // Negative inner OR is not unwrapped
        (
            or(or(.negative, term("a"), term("b")), term("c")),
            or(or(.negative, term("a"), term("b")), term("c")),
        ),
    ])
    func flattened(input: FilterQuery<PolarityString>, expected: FilterQuery<PolarityString>) {
        #expect(input.flattened() == expected)
    }

    enum Transform: Sendable {
        case identity
        case negateAll
        case alwaysNil

        func apply(_ term: PolarityString) -> PolarityString? {
            switch self {
            case .identity: term
            case .negateAll: term.negated
            case .alwaysNil: nil
            }
        }
    }

    @Test<[(FilterQuery<PolarityString>, Transform, FilterQuery<PolarityString>?)]>("transformLeaves", arguments: [
        (
            term("a"),
            Transform.identity,
            term("a"),
        ),
        (
            term("a"),
            .negateAll,
            term(.negative, "a"),
        ),
        (
            term("a"),
            .alwaysNil,
            nil,
        ),
        (
            and(term("a"), term("b")),
            .identity,
            and(term("a"), term("b")),
        ),
        (
            and(term("a"), term(.negative, "b")),
            .negateAll,
            and(term(.negative, "a"), term("b")),
        ),
        (
            and(term("a"), term("b")),
            .alwaysNil,
            nil,
        ),
        (
            or(term("a"), term("b")),
            .identity,
            or(term("a"), term("b")),
        ),
        (
            or(term("a"), term(.negative, "b")),
            .negateAll,
            or(term(.negative, "a"), term("b")),
        ),
    ])
    func transformLeaves(input: FilterQuery<PolarityString>, transform: Transform, expected: FilterQuery<PolarityString>?) {
        let actual = input.transformLeaves { transform.apply($0) }
        #expect(actual == expected)
    }
}
