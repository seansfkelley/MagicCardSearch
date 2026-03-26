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
        case digital = "Digital"
        case paper = "Paper"
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

    mutating func reset() {
        frame = .any
        text = .any
        game = .any
        sort = .releaseDate
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

    func toQueryFor(oracleId: String) -> String {
        var query = "oracleid:\(oracleId) include:extras unique:prints"

        switch frame {
        case .any:
            break
        case .retro:
            query += " frame:old"
        case .modern:
            query += " frame:new"
        }

        switch text {
        case .any:
            break
        case .normal:
            query += " -is:full"
        case .fullArt:
            query += " is:full"
        }

        switch game {
        case .any:
            break
        case .digital:
            query += " (game:mtgo OR game:arena)"
        case .paper:
            query += " game:paper"
        }

        return query
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
