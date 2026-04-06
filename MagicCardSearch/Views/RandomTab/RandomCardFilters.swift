import ScryfallKit
import Foundation

extension Format: @retroactive Codable {}

struct RandomCardFilters: Equatable, Codable {
    var colors: Set<Card.Color> = []
    var useColorIdentity: Bool = false
    var formats: Set<Format> = []
    var types: Set<String> = []
    var legendary: Bool = false
    var rarities: Set<Card.Rarity> = []
    var games: Set<Game> = []

    var queryString: String? {
        var clauses: [String] = ["language:en"]

        if !colors.isEmpty {
            let key = useColorIdentity ? "id" : "color"

            let orClauses = colors.map { "\(key):\($0.rawValue.lowercased())" }.joined(separator: " OR ")
            clauses.append("(\(orClauses)")

            let nonColorless = colors.subtracting([.C])
            if !nonColorless.isEmpty {
                clauses.append("\(key)<=\(nonColorless.map { $0.rawValue.lowercased() }.joined())")
            }
        }

        if !formats.isEmpty {
            let clause = formats.map { "format:\($0.rawValue)" }.joined(separator: " OR ")
            clauses.append("(\(clause))")
        }

        if !types.isEmpty {
            let clause = types.map { "type:\($0.lowercased())" }.joined(separator: " OR ")
            clauses.append("(\(clause))")
        }

        if legendary {
            clauses.append("type:legendary")
        }

        if !rarities.isEmpty {
            let clause = rarities.map { "rarity:\($0.rawValue)" }.joined(separator: " OR ")
            clauses.append("(\(clause))")
        }

        if !games.isEmpty {
            let clause = games.map { "game:\($0.rawValue)" }.joined(separator: " OR ")
            clauses.append("(\(clause))")
        }

        return clauses.joined(separator: " ")
    }
}
