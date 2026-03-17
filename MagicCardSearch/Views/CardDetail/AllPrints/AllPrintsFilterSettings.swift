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

    var frame: FrameFilter = .any
    var text: TextFilter = .any
    var game: GameFilter = .any

    var isDefault: Bool {
        frame == .any && text == .any && game == .any
    }

    mutating func reset() {
        frame = .any
        text = .any
        game = .any
    }

    var description: String {
        "AllPrintsFilterSettings(frame: .\(frame), text: .\(text), game: .\(game))"
    }

    func toQueryFor(oracleId: String) -> String {
        var query = "oracleid:\(oracleId) include:extras unique:prints order:released dir:desc"

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
}
