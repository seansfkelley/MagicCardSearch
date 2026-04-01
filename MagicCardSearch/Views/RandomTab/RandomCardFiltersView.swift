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
            let orClauses = colors.map { "\(key):\($0.rawValue.lowercased())" }.joined(separator: "OR")
            let combinedColorClause = "\(key)<=\(colors.map { $0.rawValue.lowercased() }.joined())"
            groups.append("(\(orClauses)) \(combinedColorClause)")
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

// MARK: - Main View

struct RandomCardFiltersView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var colors: Set<Card.Color>
    @State private var useColorIdentity: Bool
    @State private var enumerations: Set<FlattenedEnumerationFilter>
    let onApply: (RandomCardFilters) -> Void

    init(filters: RandomCardFilters, onApply: @escaping (RandomCardFilters) -> Void) {
        self.onApply = onApply

        self._colors = State(initialValue: filters.colors)
        self._useColorIdentity = State(initialValue: filters.useColorIdentity)
        self._enumerations = State(initialValue: {
            var initial = Set<FlattenedEnumerationFilter>()
            initial.formUnion(filters.types.map { .type($0) })
            initial.formUnion(filters.rarities.map { .rarity($0) })
            initial.formUnion(filters.games.map { .game($0) })
            initial.formUnion(filters.formats.map { .format($0) })
            return initial
        }())
    }

    var body: some View {
        List(selection: $enumerations) {
            ColorFilterSection(colors: $colors, useColorIdentity: $useColorIdentity)
            TypeFilterSection()
            RarityFilterSection()
            GamesFilterSection()
            FormatFilterSection(enumerations: $enumerations)
            ResetFilterSection(
                colors: $colors,
                useColorIdentity: $useColorIdentity,
                enumerations: $enumerations,
            )
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(.active))
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
                    let merged = RandomCardFilters(
                        colors: colors,
                        useColorIdentity: useColorIdentity,
                        formats: Set(enumerations.compactMap {
                            if case .format(let format) = $0 { format } else { nil }
                        }),
                        types: Set(enumerations.compactMap {
                            if case .type(let type) = $0 { type } else { nil }
                        }),
                        rarities: Set(enumerations.compactMap {
                            if case .rarity(let rarity) = $0 { rarity } else { nil }
                        }),
                        games: Set(enumerations.compactMap {
                            if case .game(let game) = $0 { game } else { nil }
                        }),
                    )
                    onApply(merged)
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(.glassProminent)
            }
        }
    }
}

private extension Card.Rarity {
    var assetName: String? {
        switch self {
        case .common: "common"
        case .uncommon: "uncommon"
        case .rare: "rare"
        case .mythic: "mythic"
        case .bonus: nil
        case .special: nil
        }
    }
}

// To use the selection mode of a List, and have that List be scrollable in a sheet, there can
// only be one List at the top level. That means that all selectable rows must be mashed into a
// single heterogenous set, which is what this type is for.
private enum FlattenedEnumerationFilter: Hashable, Identifiable {
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

    var assetName: String? {
        switch self {
        case .type(let type):
            switch type {
            case "Artifact", "Creature", "Enchantment", "Instant", "Land", "Legendary", "Planeswalker", "Sorcery": type.lowercased()
            default: nil
            }
        case .rarity(let rarity): rarity.assetName
        case .game: nil
        case .format: nil
        }
    }
}

// MARK: - Color Section

private struct ColorFilterSection: View {
    static let allColors: [Card.Color] = [.W, .U, .B, .R, .G, .C]

    @Binding var colors: Set<Card.Color>
    @Binding var useColorIdentity: Bool

    var body: some View {
        Section {
            HStack(spacing: 16) {
                ForEach(Self.allColors, id: \.self) { colorButton($0) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .selectionDisabled()

            Toggle("Color Identity", isOn: $useColorIdentity)
                .selectionDisabled()
        } header: {
            Text("Color")
        } footer: {
            if useColorIdentity {
                Text("Show cards with a color identity playable in these colors, or any color if none are selected.")
            } else {
                Text("Show cards playable in these colors, or any color if none are selected.")
            }
        }
    }

    private func colorButton(_ color: Card.Color) -> some View {
        let isSelected = colors.contains(color)
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                if isSelected {
                    colors.remove(color)
                } else {
                    colors.insert(color)
                }
            }
        } label: {
            SymbolView(SymbolCode("{\(color.rawValue)}"), size: 40, showDropShadow: true)
                .opacity(isSelected ? 1.0 : 0.4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Type Section

private struct TypeFilterSection: View {
    static let cardTypes: [FlattenedEnumerationFilter] = [
        "Artifact", "Creature", "Enchantment", "Instant", "Land", "Legendary", "Planeswalker", "Sorcery",
    ].map { .type($0) }

    var body: some View {
        Section {
            ForEach(Self.cardTypes) { type in
                HStack {
                    Text(type.label)
                    if let assetName = type.assetName {
                        Spacer()
                        Image(assetName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    }
                }
            }
        } header: {
            Text("Type")
        } footer: {
            Text("Show cards matching any of these types, or any type if none are selected.")
        }
    }
}

// MARK: - Rarity Section

private struct RarityFilterSection: View {
    static let allRarities: [FlattenedEnumerationFilter] = [
        .common, .uncommon, .rare, .mythic,
    ].map { .rarity($0) }

    var body: some View {
        Section {
            ForEach(Self.allRarities) { rarity in
                HStack {
                    Text(rarity.label)
                    if let assetName = rarity.assetName {
                        Spacer()
                        Image(assetName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    }
                }
            }
        } header: {
            Text("Rarity")
        } footer: {
            Text("Show cards matching any of these rarities, or any rarity if none are selected.")
        }
    }
}

// MARK: - Games Section

private struct GamesFilterSection: View {
    static let allGames: [FlattenedEnumerationFilter] = [
        .paper, .arena, .mtgo,
    ].map { .game($0) }

    var body: some View {
        Section {
            ForEach(Self.allGames) { game in
                Text(game.label)
                    .id(game)
            }
        } header: {
            Text("Games")
        } footer: {
            Text("Show cards printed in any of these games, or any game if none are selected.")
        }
    }
}

// MARK: - Format Section

private struct FormatFilterSection: View {
    static let aboveFoldFormats: [FlattenedEnumerationFilter] = [
        .standard, .commander, .modern, .legacy,
    ].map { .format($0) }

    static let belowFoldFormats: [FlattenedEnumerationFilter] = [
        .alchemy, .brawl, .duel, .future, .gladiator, .historic, .oathbreaker, .oldschool, .pauper,
        .paupercommander, .penny, .pioneer, .predh, .premodern, .standardbrawl, .timeless, .vintage,
    ].map { .format($0) }

    @Binding var enumerations: Set<FlattenedEnumerationFilter>
    @State private var formatsExpanded = false

    var body: some View {
        Section {
            ForEach(Self.aboveFoldFormats) { format in
                Text(format.label)
                    .id(format)
            }
            if formatsExpanded {
                ForEach(Self.belowFoldFormats.enumerated(), id: \.element) { index, format in
                    Text(format.label)
                        .id(format)
                        .if(index == 0) { view in
                            view.listRowSeparatorTint(.secondary, edges: .top)
                        }
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
            Text("Show cards legal in any of these formats, or any format if none are selected.")
        }
        .onAppear {
            let allBelowFoldFormats = Self.belowFoldFormats.compactMap {
                if case .format(let format) = $0 { format } else { nil }
            }
            let selectedFormats = Set(enumerations.compactMap {
                if case .format(let format) = $0 { format } else { nil }
            })
            if !selectedFormats.isDisjoint(with: allBelowFoldFormats) {
                formatsExpanded = true
            }
        }
    }
}

// MARK: - Reset Section

private struct ResetFilterSection: View {
    @Binding var colors: Set<Card.Color>
    @Binding var useColorIdentity: Bool
    @Binding var enumerations: Set<FlattenedEnumerationFilter>

    private var areFiltersDefault: Bool {
        colors.isEmpty && useColorIdentity == false && enumerations.isEmpty
    }

    var body: some View {
        // By making this a footer of a Section instead of a bare item or content in a Section, we
        // seem to get better visuals and interactions because the List doesn't consider it to be
        // a regular item, and we don't get an extra layer of bordering from the Section itself.
        Section {} footer: {
            Button(role: .destructive) {
                colors = []
                useColorIdentity = false
                enumerations = []
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset to Defaults")
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(areFiltersDefault ? .gray : .red)
            }
            .disabled(areFiltersDefault)
        }
    }
}

#Preview {
    NavigationStack {
        RandomCardFiltersView(filters: RandomCardFilters()) {
            print($0)
        }
    }
    .environment(ScryfallCatalogs())
}
