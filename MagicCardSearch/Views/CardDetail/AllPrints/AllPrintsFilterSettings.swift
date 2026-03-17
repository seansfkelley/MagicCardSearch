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
        case .releaseDate:
            cards.sorted {
                ($0.releasedAtAsDate ?? .distantPast) > ($1.releasedAtAsDate ?? .distantPast)
            }
        case .regularPrice:
            cards.sorted {
                ($0.prices.usd.flatMap(Double.init) ?? -.infinity, $0.releasedAtAsDate ?? .distantPast)
                    > ($1.prices.usd.flatMap(Double.init) ?? -.infinity, $1.releasedAtAsDate ?? .distantPast)
            }
        case .foilPrice:
            cards.sorted {
                ($0.prices.usdFoil.flatMap(Double.init) ?? -.infinity, $0.releasedAtAsDate ?? .distantPast)
                    > ($1.prices.usdFoil.flatMap(Double.init) ?? -.infinity, $1.releasedAtAsDate ?? .distantPast)
            }
        }
    }
}
