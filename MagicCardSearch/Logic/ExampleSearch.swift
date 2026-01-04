import Foundation

struct ExampleSearch: Hashable {
    let title: String
    let filters: [SearchFilter]
    
    private static let examples: [ExampleSearch] = [
        .init(title: "Modern-Legal U/R Pingers", filters: [
            .basic(false, "color", .lessThanOrEqual, "ur"),
            .basic(false, "function", .including, "pinger"),
            .basic(false, "format", .including, "modern"),
        ]),
        .init(title: "Biggest Dragons", filters: [
            .basic(false, "type", .including, "dragon"),
            .basic(false, "order", .including, "power"),
            .basic(false, "dir", .including, "desc"),
        ]),
        .init(title: "Most Devoted Green Permanents", filters: [
            .basic(false, "devotion", .greaterThanOrEqual, "gggg"),
            .basic(false, "order", .including, "manavalue"),
            .basic(false, "dir", .including, "desc"),
        ]),
        .init(title: "All Non-basic-land Textless Cards", filters: [
            .basic(false, "is", .including, "textless"),
            .basic(true, "type", .including, "basic"),
        ]),
        .init(title: "Five-color Artifacts", filters: [
            .basic(false, "type", .including, "artifact"),
            .basic(false, "id", .equal, "5"),
        ]),
        .init(title: "Real Cards with Funny Rulings", filters: [
            .basic(false, "function", .including, "fun-ruling"),
            .basic(true, "is", .including, "funny"),
        ]),
        .init(title: "Future Sight Frames", filters: [
            .basic(false, "frame", .including, "future"),
        ]),
        .init(title: "Cheap, Top-heavy Red Creatures", filters: [
            .basic(false, "power", .greaterThan, "toughness"),
            .basic(false, "color", .equal, "red"),
            .basic(false, "manavalue", .lessThanOrEqual, "2"),
        ]),
        .init(title: "White Self-sacrifice", filters: [
            .basic(false, "color", .including, "white"),
            .regex(false, "oracle", .including, "^sacrifice ~"),
        ]),
        .init(title: "Most Expensive 1-Drops in Standard", filters: [
            .basic(false, "manavalue", .equal, "1"),
            .basic(false, "format", .including, "standard"),
            .basic(false, "order", .including, "usd"),
            .basic(false, "dir", .including, "desc"),
        ]),
        .init(title: "Best Boros Combat Tricks", filters: [
            .basic(false, "color", .lessThanOrEqual, "boros"),
            .basic(false, "function", .including, "combat-trick"),
            .basic(false, "order", .including, "edhrec"),
            .basic(false, "dir", .including, "asc"),
        ]),
        .init(title: "Best Orzhov Commanders", filters: [
            .basic(false, "id", .equal, "orzhov"),
            .basic(false, "type", .including, "legendary"),
            .basic(false, "type", .including, "creature"),
            .basic(false, "format", .including, "commander"),
            .basic(false, "order", .including, "edhrec"),
            .basic(false, "dir", .including, "asc"),
        ]),
        .init(title: "Muraganda Petroglyphs \"Synergy\"", filters: [
            .basic(false, "type", .including, "creature"),
            .basic(false, "is", .including, "vanilla"),
            .basic(true, "is", .including, "token"),
        ]),
        .init(title: "Morphling and Friends", filters: [
            .regex(false, "name", .including, "^[^\\s]+ling$"),
            .basic(false, "type", .including, "shapeshifter"),
        ]),
        .init(title: "Stained Glass", filters: [
            .basic(false, "art", .including, "stained-glass"),
        ]),
        .init(title: "Green Can Do Anything", filters: [
            .basic(false, "color", .including, "green"),
            .basic(false, "function", .including, "color-break"),
        ]),
        .init(title: "Dog Tongues", filters: [
            .basic(false, "art", .including, "dog"),
            .basic(false, "art", .including, "tongue-sticking-out"),
        ]),
        .init(title: "Most Color-committed Cards", filters: [
            .basic(false, "color", .equal, "1"),
            .basic(true, "mana", .including, "{1}"),
            .basic(true, "is", .including, "hybrid"),
            .basic(false, "manavalue", .greaterThanOrEqual, "4"),
        ]),
        .init(title: "Most Reprinted Cards", filters: [
            .basic(false, "prints", .greaterThan, "30"),
        ]),
        .init(title: "John Avon's Landscapes", filters: [
            .basic(false, "artist", .including, "John Avon"),
            .basic(false, "type", .including, "land"),
            .basic(false, "unique", .including, "art"),
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
