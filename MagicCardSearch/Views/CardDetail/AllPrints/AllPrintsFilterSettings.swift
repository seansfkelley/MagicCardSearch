import Foundation
import ScryfallKit

struct AllPrintsFilterSettings: Equatable, Hashable, CustomStringConvertible {
    enum FrameFilter: String, CaseIterable {
        case any = "Any"
        case retro = "Retro"
        case modern = "Modern"
    }

    enum TextFilter: String, CaseIterable {
        case any = "Any"
        case normal = "Normal"
        case fullArt = "Full-art"
    }

    enum GameFilter: String, CaseIterable {
        case any = "Any"
        case paper = "Paper"
        case arena = "Arena"
        case mtgo = "MTGO"
    }

    enum SortMode: String, CaseIterable {
        case releaseDate = "Released"
        case regularPrice = "Reg. Price"
        case foilPrice = "Foil Price"
    }

    var frame: FrameFilter = .any
    var text: TextFilter = .any
    var game: GameFilter = .any
    var sort: SortMode = .releaseDate

    // Whether the fetch-affecting settings (everything except sort) are at their defaults.
    var isDefaultFilterSettings: Bool {
        frame == .any && text == .any && game == .any
    }

    var isDefault: Bool {
        isDefaultFilterSettings && sort == .releaseDate
    }

    var description: String {
        "AllPrintsFilterSettings(frame: .\(frame), text: .\(text), game: .\(game), sort: .\(sort))"
    }

    // Returns a settings value that only contains the fetch-affecting fields, used as a cache key.
    var fetchKey: FetchKey {
        FetchKey(frame: frame, text: text, game: game)
    }

    struct FetchKey: Equatable, Hashable {
        let frame: FrameFilter
        let text: TextFilter
        let game: GameFilter
    }

    func toFiltersFor(oracleId: String) -> [FilterTerm] {
        var filters: [FilterTerm] = [
            .basic(.positive, "oracleid", .including, oracleId),
            .basic(.positive, "include", .including, "extras"),
            .basic(.positive, "unique", .including, "prints"),
        ]

        switch frame {
        case .any:
            break
        case .retro:
            filters.append(.basic(.positive, "frame", .including, "old"))
        case .modern:
            filters.append(.basic(.positive, "frame", .including, "new"))
        }

        switch text {
        case .any:
            break
        case .normal:
            filters.append(.basic(.negative, "is", .including, "full"))
        case .fullArt:
            filters.append(.basic(.positive, "is", .including, "full"))
        }

        switch game {
        case .any:
            break
        case .paper:
            filters.append(.basic(.positive, "game", .including, "paper"))
        case .arena:
            filters.append(.basic(.positive, "game", .including, "arena"))
        case .mtgo:
            filters.append(.basic(.positive, "game", .including, "mtgo"))
        }

        return filters
    }

    func sort(_ cards: [Card]) -> [Card] {
        switch sort {
        case .releaseDate: cards.sorted { $0.releaseDateSortKey > $1.releaseDateSortKey }
        case .regularPrice: cards.sorted { $0.regularPriceSortKey > $1.regularPriceSortKey }
        case .foilPrice: cards.sorted { $0.foilPriceSortKey > $1.foilPriceSortKey }
        }
    }
}

private extension Card {
    var releaseDateSortKey: (Date, String, String) {
        (
            releasedAtAsDate ?? .distantPast,
            setName,
            collectorNumber,
        )
    }

    // swiftlint:disable:next large_tuple
    var regularPriceSortKey: (Double, Double, Date, String, String) {
        (
            prices.usd.flatMap(Double.init) ?? -.infinity,
            prices.usdFoil.flatMap(Double.init) ?? -.infinity,
            releasedAtAsDate ?? .distantPast,
            setName,
            collectorNumber,
        )
    }

    // swiftlint:disable:next large_tuple
    var foilPriceSortKey: (Double, Double, Date, String, String) {
        (
            prices.usdFoil.flatMap(Double.init) ?? -.infinity,
            prices.usd.flatMap(Double.init) ?? -.infinity,
            releasedAtAsDate ?? .distantPast,
            setName,
            collectorNumber,
        )
    }
}
