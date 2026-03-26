public struct PolarityString: FilterQueryLeaf {
    let polarity: Polarity
    let string: String

    init(_ polarity: Polarity, _ string: String) {
        self.polarity = polarity
        self.string = string
    }

    public var description: String { "\(polarity.description)\(string)" }
    public var negated: PolarityString { .init(polarity.negated, string) }
}

public typealias PartialFilterQuery = FilterQuery<PolarityString>
