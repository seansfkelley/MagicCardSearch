import SwiftUI
import ScryfallKit

struct RandomCardFilters: Equatable {
    enum Game: String {
        case paper, arena, mtgo
    }

    var colors: Set<Card.Color> = []
    var useColorIdentity = false
    var formats: Set<Format> = []
    var types: Set<String> = []
    var rarities: Set<Card.Rarity> = []
    var games: Set<Game> = []

    var queryString: String {
        var groups: [String] = ["language:en"]

        if !colors.isEmpty {
            let key = useColorIdentity ? "id" : "color"
            let clause = "\(key)<=\(colors.map { $0.rawValue.lowercased() }.joined())"
            groups.append(clause)
        }

        if !formats.isEmpty {
            let clause = formats.map { "format:\($0.rawValue)" }.joined(separator: " OR ")
            groups.append("(\(clause))")
        }

        if !types.isEmpty {
            let clause = types.map { "type:\($0.lowercased())" }.joined(separator: " OR ")
            groups.append("(\(clause))")
        }

        if !rarities.isEmpty {
            let clause = rarities.map { "rarity:\($0.rawValue)" }.joined(separator: " OR ")
            groups.append("(\(clause))")
        }

        if !games.isEmpty {
            let clause = games.map { "game:\($0.rawValue)" }.joined(separator: " OR ")
            groups.append("(\(clause))")
        }

        return groups.joined(separator: " ")
    }
}

struct RandomCardFiltersView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: RandomCardFilters
    let onApply: (RandomCardFilters) -> Void

    init(filters: RandomCardFilters, onApply: @escaping (RandomCardFilters) -> Void) {
        self._draft = State(initialValue: filters)
        self.onApply = onApply
    }

    var body: some View {
        ScrollView {
            colorSection
            typeSection
            raritySection
            gamesSection
            formatSection
            resetSection
        }
        .navigationTitle("Filters")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    onApply(draft)
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(.glassProminent)
            }
        }
    }

    // MARK: - Color Section

    private static let allColors: [Card.Color] = [.W, .U, .B, .R, .G, .C]

    private var colorSection: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    ForEach(Self.allColors, id: \.self) { colorButton($0) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

                Toggle("Color Identity", isOn: $draft.useColorIdentity)
            } header: {
                Text("Color")
            } footer: {
                if draft.colors.isEmpty {
                    Text("Not currently filtering by color.")
                } else if draft.useColorIdentity {
                    Text("Show cards with a color identity playable in these colors.")
                } else {
                    Text("Show cards playable in these colors.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollDisabled(true)
    }

    private func colorButton(_ color: Card.Color) -> some View {
        let isSelected = draft.colors.contains(color)
        return Button {
            if isSelected {
                draft.colors.remove(color)
            } else {
                draft.colors.insert(color)
            }
        } label: {
            SymbolView(SymbolCode("{\(color.rawValue)}"), size: 40, showDropShadow: true)
                .opacity(isSelected ? 1.0 : 0.4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Type Section

    private static let cardTypes = [
        "Artifact", "Creature", "Enchantment", "Instant", "Land", "Legendary", "Planeswalker", "Sorcery",
    ]

    private var typeSection: some View {
        List(selection: $draft.types) {
            Section {
                ForEach(Self.cardTypes, id: \.self) { Text($0) }
            } header: {
                Text("Type")
            } footer: {
                Text(draft.types.isEmpty
                     ? "Not currently filtering by type."
                     : "Show cards matching any of these types.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollDisabled(true)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Rarity Section

    private static let allRarities: [(Card.Rarity, String)] = [
        (.common, "Common"),
        (.uncommon, "Uncommon"),
        (.rare, "Rare"),
        (.mythic, "Mythic"),
    ]

    private var raritySection: some View {
        List(selection: $draft.rarities) {
            Section {
                ForEach(Self.allRarities, id: \.0) { rarity, label in
                    Text(label)
                }
            } header: {
                Text("Rarity")
            } footer: {
                Text(draft.rarities.isEmpty
                     ? "Not currently filtering by rarity."
                     : "Show cards matching any of these rarities.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollDisabled(true)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Games Section

    private static let allGames: [(RandomCardFilters.Game, String)] = [
        (.paper, "Paper"),
        (.arena, "Arena"),
        (.mtgo, "MTGO"),
    ]

    private var gamesSection: some View {
        List(selection: $draft.games) {
            Section {
                ForEach(Self.allGames, id: \.0) { game, label in
                    Text(label)
                }
            } header: {
                Text("Games")
            } footer: {
                Text(draft.games.isEmpty
                     ? "Not currently filtering by game type."
                     : "Show cards printed into any of these games.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollDisabled(true)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Format Section

    private static let aboveFoldFormats: [Format] = [.standard, .commander, .modern, .legacy]
    private static let belowFoldFormats: [Format] = [
        .alchemy, .brawl, .duel, .future, .gladiator, .historic,
        .oathbreaker, .oldschool, .pauper, .paupercommander, .penny,
        .pioneer, .predh, .premodern, .standardbrawl, .timeless, .vintage,
    ]

    @State private var formatsExpanded = false

    private var formatSection: some View {
        List(selection: $draft.formats) {
            Section {
                ForEach(Self.aboveFoldFormats, id: \.self) { format in
                    Text(format.label)
                }
                if formatsExpanded {
                    ForEach(Self.belowFoldFormats, id: \.self) { format in
                        Text(format.label)
                    }
                }
            } header: {
                Text("Format")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    if !formatsExpanded {
                        Button("Show More") {
                            withAnimation { formatsExpanded = true }
                        }
                    }
                    Text(draft.formats.isEmpty
                         ? "Not currently filtering by legality."
                         : "Show cards legal in any of these formats.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollDisabled(true)
        .environment(\.editMode, .constant(.active))
        .onAppear {
            if !draft.formats.isDisjoint(with: Self.belowFoldFormats) {
                formatsExpanded = true
            }
        }
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        List {
            Section {
                Button("Reset to Defaults", role: .destructive) {
                    draft = RandomCardFilters()
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollDisabled(true)
    }
}

#Preview {
    NavigationStack {
        RandomCardFiltersView(filters: RandomCardFilters()) { _ in }
    }
}
