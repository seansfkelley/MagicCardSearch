import SwiftUI
import ScryfallKit

// MARK: - Main View

struct RandomCardFiltersView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var colors: Set<Card.Color>
    @State private var useColorIdentity: Bool
    @State private var legendary: Bool
    @State private var enumerations: Set<FlattenedEnumerationFilter>
    @State private var setCode: SetCode?
    @State private var showingSetPicker = false
    let onApply: (RandomCardFilters) -> Void

    init(filters: RandomCardFilters, onApply: @escaping (RandomCardFilters) -> Void) {
        self.onApply = onApply

        self._colors = State(initialValue: filters.colors)
        self._useColorIdentity = State(initialValue: filters.useColorIdentity)
        self._legendary = State(initialValue: filters.legendary)
        self._setCode = State(initialValue: filters.setCode)
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
            TypeFilterSection(legendary: $legendary)
            SetFilterSection(setCode: $setCode, showingSetPicker: $showingSetPicker)
            FormatFilterSection(enumerations: $enumerations)
            RarityFilterSection()
            GamesFilterSection()
            ResetFilterSection(
                colors: $colors,
                useColorIdentity: $useColorIdentity,
                legendary: $legendary,
                enumerations: $enumerations,
                setCode: $setCode,
            )
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(.active))
        .navigationDestination(isPresented: $showingSetPicker) {
            SetPickerView(setCode: $setCode)
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
                    let merged = RandomCardFilters(
                        colors: colors,
                        useColorIdentity: useColorIdentity,
                        formats: Set(enumerations.compactMap {
                            if case .format(let format) = $0 { format } else { nil }
                        }),
                        types: Set(enumerations.compactMap {
                            if case .type(let type) = $0 { type } else { nil }
                        }),
                        legendary: legendary,
                        rarities: Set(enumerations.compactMap {
                            if case .rarity(let rarity) = $0 { rarity } else { nil }
                        }),
                        games: Set(enumerations.compactMap {
                            if case .game(let game) = $0 { game } else { nil }
                        }),
                        setCode: setCode,
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
            case "Artifact", "Creature", "Enchantment", "Instant", "Land", "Planeswalker", "Sorcery": type.lowercased()
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
                Text("If set, show cards matching any of these colors that are legal in a deck with this color identity.")
            } else {
                Text("If set, show cards matching any of these colors, and no more than these colors.")
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
        "Artifact", "Creature", "Enchantment", "Instant", "Land", "Planeswalker", "Sorcery",
    ].map { .type($0) }

    @Binding var legendary: Bool

    var body: some View {
        Section {
            Toggle("Legendary", isOn: $legendary)
                .selectionDisabled()
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
            Text("If set, only show cards matching at least one of these types.")
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
            Text("If set, only show cards matching one of these rarities.")
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
            Text("If set, only show cards printed in at least one of these games.")
        }
    }
}

// MARK: - Set Section

private struct SetFilterSection: View {
    @Environment(ScryfallCatalogs.self) private var scryfallCatalogs
    @Binding var setCode: SetCode?
    @Binding var showingSetPicker: Bool

    var body: some View {
        Section {
            HStack(spacing: 12) {
                if let setCode, let set = scryfallCatalogs.sets?[setCode] {
                    SetIconView(setCode: setCode, size: 20)
                        .foregroundStyle(.primary)
                    Text(set.name)
                        .foregroundStyle(.primary)
                    Spacer()
                    Button {
                        self.setCode = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("No set selected")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingSetPicker = true
            }
            .selectionDisabled()
        } header: {
            Text("Set")
        } footer: {
            Text("If set, only show cards from this set.")
        }
    }
}

// MARK: - Set Picker

private struct SetPickerView: View {
    private struct SetSection: Identifiable {
        let fullSectionName: String
        let shortSectionName: String
        let sets: [MTGSet]

        var id: String { fullSectionName }

        init(_ fullSectionName: String, shortSectionName: String? = nil, sets: [MTGSet]) {
            self.fullSectionName = fullSectionName
            self.shortSectionName = shortSectionName ?? fullSectionName
            self.sets = sets
        }
    }

    private let ignoredSetTypes: Set<MTGSet.Kind> = [
        .token,
        .promo,
        .memorabilia,
        .minigame,
        .duelDeck,
    ]

    @Environment(ScryfallCatalogs.self) private var scryfallCatalogs
    @Environment(\.dismiss) private var dismiss
    @Binding var setCode: SetCode?

    private enum SortOrder {
        case byReleaseDate, alphabetical
    }

    @State private var sortOrder: SortOrder = .byReleaseDate
    @State private var sections: [SetSection] = []

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.sets, id: \.code) { set in
                        Button {
                            setCode = SetCode(set.code)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                SetIconView(setCode: SetCode(set.code), size: 32)
                                Text(set.name)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .sectionIndexLabel(section.shortSectionName)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Set")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Sort", selection: $sortOrder) {
                    Text("Release Date").tag(SortOrder.byReleaseDate)
                    Text("Name").tag(SortOrder.alphabetical)
                }
                .pickerStyle(.segmented)
            }
        }
        .task(id: sortOrder) {
            sections = buildSections(sortOrder: sortOrder)
        }
    }

    private func buildSections(sortOrder: SortOrder) -> [SetSection] {
        let all = Array((scryfallCatalogs.sets ?? [:]).values)
            .filter { !ignoredSetTypes.contains($0.setType) }

        return switch sortOrder {
        case .byReleaseDate: dateSections(from: all)
        case .alphabetical: alphabetSections(from: all)
        }
    }

    private func dateSections(from sets: [MTGSet]) -> [SetSection] {
        let sorted = sets.sorted {
            ($0.releasedAtAsDate ?? .distantPast) > ($1.releasedAtAsDate ?? .distantPast)
        }
        let grouped = Dictionary(grouping: sorted) { set -> String in
            if let date = set.releasedAtAsDate {
                return String(Calendar.current.component(.year, from: date))
            }
            return "—"
        }
        let keys = grouped.keys.sorted { lhs, rhs in
            if lhs == "—" { return false }
            if rhs == "—" { return true }
            return lhs > rhs
        }
        return keys.map { SetSection($0, shortSectionName: "'\($0.suffix(2))", sets: grouped[$0]!) }
    }

    private func alphabetSections(from sets: [MTGSet]) -> [SetSection] {
        let sorted = sets.sorted { $0.name < $1.name }
        let grouped = Dictionary(grouping: sorted) { set -> String in
            if let first = set.name.first, first.isASCII && first.isLetter {
                return String(first).uppercased()
            }
            return "#"
        }
        var result = grouped.keys
            .filter { $0 != "#" }
            .sorted()
            .map { SetSection($0, sets: grouped[$0]!) }
        if let hashSets = grouped["#"] {
            result.append(SetSection("#", sets: hashSets))
        }
        return result
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
            Text("If set, only show cards legal in at least one of these formats.")
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
    @Binding var legendary: Bool
    @Binding var enumerations: Set<FlattenedEnumerationFilter>
    @Binding var setCode: SetCode?

    private var areFiltersDefault: Bool {
        colors.isEmpty && useColorIdentity == false && legendary == false && enumerations.isEmpty && setCode == nil
    }

    var body: some View {
        // By making this a footer of a Section instead of a bare item or content in a Section, we
        // seem to get better visuals and interactions because the List doesn't consider it to be
        // a regular item, and we don't get an extra layer of bordering from the Section itself.
        Section {} footer: {
            Button(role: .destructive) {
                colors = []
                useColorIdentity = false
                legendary = false
                enumerations = []
                setCode = nil
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
