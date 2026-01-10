import Foundation

struct ExampleSearch: Hashable {
    let title: String
    let filters: [FilterTerm]

    private static let examples: [ExampleSearch] = [
        .init(title: "Modern-Legal U/R Pingers", filters: [
            .basic(.positive, "color", .lessThanOrEqual, "ur"),
            .basic(.positive, "function", .including, "pinger"),
            .basic(.positive, "format", .including, "modern"),
        ]),
        .init(title: "Biggest Dragons", filters: [
            .basic(.positive, "type", .including, "dragon"),
            .basic(.positive, "order", .including, "power"),
            .basic(.positive, "dir", .including, "desc"),
        ]),
        .init(title: "Most Devoted Green Permanents", filters: [
            .basic(.positive, "devotion", .greaterThanOrEqual, "gggg"),
            .basic(.positive, "order", .including, "manavalue"),
            .basic(.positive, "dir", .including, "desc"),
        ]),
        .init(title: "All Non-basic-land Textless Cards", filters: [
            .basic(.positive, "is", .including, "textless"),
            .basic(.negative, "type", .including, "basic"),
        ]),
        .init(title: "Five-color Artifacts", filters: [
            .basic(.positive, "type", .including, "artifact"),
            .basic(.positive, "id", .equal, "5"),
        ]),
        .init(title: "Real Cards with Funny Rulings", filters: [
            .basic(.positive, "function", .including, "fun-ruling"),
            .basic(.negative, "is", .including, "funny"),
        ]),
        .init(title: "Future Sight Frames", filters: [
            .basic(.positive, "frame", .including, "future"),
        ]),
        .init(title: "Cheap, Top-heavy Red Creatures", filters: [
            .basic(.positive, "power", .greaterThan, "toughness"),
            .basic(.positive, "color", .equal, "red"),
            .basic(.positive, "manavalue", .lessThanOrEqual, "2"),
        ]),
        .init(title: "White Self-sacrifice", filters: [
            .basic(.positive, "color", .including, "white"),
            .regex(.positive, "oracle", .including, "^sacrifice ~"),
        ]),
        .init(title: "Most Expensive 1-Drops in Standard", filters: [
            .basic(.positive, "manavalue", .equal, "1"),
            .basic(.positive, "format", .including, "standard"),
            .basic(.positive, "order", .including, "usd"),
            .basic(.positive, "dir", .including, "desc"),
        ]),
        .init(title: "Best Boros Combat Tricks", filters: [
            .basic(.positive, "color", .lessThanOrEqual, "boros"),
            .basic(.positive, "function", .including, "combat-trick"),
            .basic(.positive, "order", .including, "edhrec"),
            .basic(.positive, "dir", .including, "asc"),
        ]),
        .init(title: "Best Orzhov Commanders", filters: [
            .basic(.positive, "id", .equal, "orzhov"),
            .basic(.positive, "type", .including, "legendary"),
            .basic(.positive, "type", .including, "creature"),
            .basic(.positive, "format", .including, "commander"),
            .basic(.positive, "order", .including, "edhrec"),
            .basic(.positive, "dir", .including, "asc"),
        ]),
        .init(title: "Muraganda Petroglyphs \"Synergy\"", filters: [
            .basic(.positive, "type", .including, "creature"),
            .basic(.positive, "is", .including, "vanilla"),
            .basic(.negative, "is", .including, "token"),
        ]),
        .init(title: "Morphling and Friends", filters: [
            .regex(.positive, "name", .including, "^[^\\s]+ling$"),
            .basic(.positive, "type", .including, "shapeshifter"),
        ]),
        .init(title: "Stained Glass", filters: [
            .basic(.positive, "art", .including, "stained-glass"),
        ]),
        .init(title: "Green Can Do Anything", filters: [
            .basic(.positive, "color", .including, "green"),
            .basic(.positive, "function", .including, "color-break"),
        ]),
        .init(title: "Dog Tongues", filters: [
            .basic(.positive, "art", .including, "dog"),
            .basic(.positive, "art", .including, "tongue-sticking-out"),
        ]),
        .init(title: "Most Color-committed Cards", filters: [
            .basic(.positive, "color", .equal, "1"),
            .basic(.negative, "mana", .including, "{1}"),
            .basic(.negative, "is", .including, "hybrid"),
            .basic(.positive, "manavalue", .greaterThanOrEqual, "4"),
        ]),
        .init(title: "Most Reprinted Cards", filters: [
            .basic(.positive, "prints", .greaterThan, "30"),
        ]),
        .init(title: "John Avon's Landscapes", filters: [
            .basic(.positive, "artist", .including, "John Avon"),
            .basic(.positive, "type", .including, "land"),
            .basic(.positive, "unique", .including, "art"),
        ]),
    ]

    private static func hourlySeed() -> Int {
        let components = Calendar.current.dateComponents([.month, .day, .hour], from: Date())
        return (components.month ?? 0) * 97 + (components.day ?? 0) * 31 + (components.hour ?? 0)
    }

    static var dailyExamples: [ExampleSearch] {
        // Swift doesn't have seedable RNGs in the standard library, so just bang together a one-off
        // calculation for our purposes. This is so it doesn't change every. single. time. it renders.
        let seed = hourlySeed()

        var chosenExamples: [ExampleSearch] = []
        for i in [7, 37, 89] {
            for j in 0..<examples.count {
                let example = examples[(seed * i + j) % examples.count]
                if !chosenExamples.contains(example) {
                    chosenExamples.append(example)
                    break
                }
            }
        }
        return chosenExamples
    }
}
