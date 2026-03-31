import SwiftUI
import ScryfallKit

struct RandomCardFilters: Equatable {
    var colors: Set<Card.Color> = []
    var useColorIdentity = false
    var formats: Set<Format> = []
    var types: Set<String> = []
    var rarities: Set<Card.Rarity> = []
    var games: Set<Game> = []

    var queryString: String? {
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

        return groups.isEmpty ? nil : groups.joined(separator: " ")
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

    private var draftBinding: Binding<Set<FilterSelection>> {
        Binding(
            get: {
                var selection = Set<FilterSelection>()
                selection.formUnion(draft.types.map { .type($0) })
                selection.formUnion(draft.rarities.map { .rarity($0) })
                selection.formUnion(draft.games.map { .game($0) })
                selection.formUnion(draft.formats.map { .format($0) })
                return selection
            },
            set: { newValue in
                draft = .init(
                    colors: draft.colors,
                    useColorIdentity: draft.useColorIdentity,
                    formats: Set(newValue.compactMap {
                        if case .format(let format) = $0 { format } else { nil }
                    }),
                    types: Set(newValue.compactMap {
                        if case .type(let type) = $0 { type } else { nil }
                    }),
                    rarities: Set(newValue.compactMap {
                        if case .rarity(let rarity) = $0 { rarity } else { nil }
                    }),
                    games: Set(newValue.compactMap {
                        if case .game(let game) = $0 { game } else { nil }
                    }),
                )
            }
        )
    }

    // MARK: - Selection

    private enum FilterSelection: Hashable, Identifiable {
        case type(String)
        case rarity(Card.Rarity)
        case game(Game)
        case format(Format)

        var id: Self { self }

        var label: String {
            switch self {
            case .type(let type): type
            case .rarity(let rarity): rarity.label
            case .game(let game): game.label
            case .format(let format): format.label
            }
        }
    }

    // MARK: - Body

    var body: some View {
        List(selection: draftBinding) {
            colorSection
            typeSection
            raritySection
            gamesSection
            formatSection
            resetSection
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(.transient))
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
        Section {
            HStack(spacing: 16) {
                ForEach(Self.allColors, id: \.self) { colorButton($0) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .selectionDisabled()

            Toggle("Color Identity", isOn: $draft.useColorIdentity)
                .selectionDisabled()
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

    private static let cardTypes: [FilterSelection] = [
        "Artifact", "Creature", "Enchantment", "Instant", "Land", "Legendary", "Planeswalker", "Sorcery",
    ].map { .type($0) }

    private var typeSection: some View {
        Section {
            ForEach(Self.cardTypes) { type in
                Text(type.label)
                    .id(type)
            }
        } header: {
            Text("Type")
        } footer: {
            Text(draft.types.isEmpty
                 ? "Not currently filtering by type."
                 : "Show cards matching any of these types.")
        }
    }

    // MARK: - Rarity Section

    private static let allRarities: [FilterSelection] = [
        .common, .uncommon, .rare, .mythic,
    ].map { .rarity($0) }

    private var raritySection: some View {
        Section {
            ForEach(Self.allRarities) { rarity in
                Text(rarity.label)
                    .id(rarity)
            }
        } header: {
            Text("Rarity")
        } footer: {
            Text(draft.rarities.isEmpty
                 ? "Not currently filtering by rarity."
                 : "Show cards matching any of these rarities.")
        }
    }

    // MARK: - Games Section

    private static let allGames: [FilterSelection] = [
        .paper, .arena, .mtgo,
    ].map { .game($0) }

    private var gamesSection: some View {
        Section {
            ForEach(Self.allGames) { game in
                Text(game.label)
                    .id(game)
            }
        } header: {
            Text("Games")
        } footer: {
            Text(draft.games.isEmpty
                 ? "Not currently filtering by game type."
                 : "Show cards printed into any of these games.")
        }
    }

    // MARK: - Format Section

    private static let aboveFoldFormats: [FilterSelection] = [
        .standard, .commander, .modern, .legacy,
    ].map { .format($0) }

    private static let belowFoldFormats: [FilterSelection] = [
        .alchemy, .brawl, .duel, .future, .gladiator, .historic, .oathbreaker, .oldschool, .pauper,
        .paupercommander, .penny, .pioneer, .predh, .premodern, .standardbrawl, .timeless, .vintage,
    ].map { .format($0) }

    @State private var formatsExpanded = false

    private var formatSection: some View {
        Section {
            ForEach(Self.aboveFoldFormats) { format in
                Text(format.label)
                    .id(format)
            }
            if formatsExpanded {
                ForEach(Self.belowFoldFormats) { format in
                    Text(format.label)
                        .id(format)
                }
            } else {
                Button("Show More") {
                    withAnimation { formatsExpanded = true }
                }
                .selectionDisabled()
            }
        } header: {
            Text("Format")
        } footer: {
            Text(draft.formats.isEmpty
                 ? "Not currently filtering by legality."
                 : "Show cards legal in any of these formats.")
        }
        .onAppear {
            let belowFoldRawFormats = Self.belowFoldFormats.compactMap {
                if case .format(let f) = $0 { f } else { nil }
            }
            if !draft.formats.isDisjoint(with: belowFoldRawFormats) {
                formatsExpanded = true
            }
        }
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        Section {
            Button("Reset to Defaults", role: .destructive) {
                draft = RandomCardFilters()
            }
            .selectionDisabled()
        }
    }
}

#Preview {
    NavigationStack {
        RandomCardFiltersView(filters: RandomCardFilters()) { _ in }
    }
}
