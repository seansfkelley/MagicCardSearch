import SwiftUI
import ScryfallKit

struct RandomCardFilters: Equatable {
    var colors: Set<Card.Color> = []
    var useColorIdentity = false
    var formats: Set<Format> = []
    var types: Set<String> = []
    var rarities: Set<Card.Rarity> = []

    var queryString: String? {
        var groups: [String] = ["language:en"]

        if !colors.isEmpty {
            let key = useColorIdentity ? "id" : "color"
            let clause = colors.map { "\(key):\($0.rawValue.lowercased())" }.joined(separator: " OR ")
            groups.append("(\(clause))")
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

    var body: some View {
        Form {
            colorSection
            formatSection
            typeSection
            raritySection

            Section {
                Button("Reset to Defaults", role: .destructive) {
                    draft = RandomCardFilters()
                }
            }
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
            }
        }
    }

    // MARK: - Color Section

    private static let allColors: [Card.Color] = [.W, .U, .B, .R, .G, .C]

    @ViewBuilder
    private var colorSection: some View {
        Section {
            HStack(spacing: 12) {
                ForEach(Self.allColors, id: \.self) { color in
                    colorButton(color)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)

            Toggle("Color identity", isOn: $draft.useColorIdentity)
        } header: {
            Text("Color")
        } footer: {
            draft.useColorIdentity
                ? Text("Show cards with a color identity .")
                : Text("Show cards matching any of these colors.")
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
            SymbolView(SymbolCode("{\(color.rawValue)}"), size: 32, showDropShadow: true)
                .opacity(isSelected ? 1.0 : 0.3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Format Section

    private static let aboveFoldFormats: [Format] = [.standard, .modern, .legacy, .commander]
    private static let belowFoldFormats: [Format] = [
        .pioneer, .historic, .timeless, .vintage, .pauper, .penny,
        .brawl, .standardbrawl, .alchemy, .gladiator, .oathbreaker,
        .paupercommander, .duel, .oldschool, .premodern, .predh, .future,
    ]

    @State private var formatsExpanded = false

    @ViewBuilder
    private var formatSection: some View {
        Section {
            FlowLayout(spacing: 8) {
                ForEach(Self.aboveFoldFormats, id: \.self) { format in
                    chipButton(format.label, isSelected: draft.formats.contains(format)) {
                        draft.formats.toggle(format)
                    }
                }

                if formatsExpanded {
                    ForEach(Self.belowFoldFormats, id: \.self) { format in
                        chipButton(format.label, isSelected: draft.formats.contains(format)) {
                            draft.formats.toggle(format)
                        }
                    }
                }
            }
            .padding(.vertical, 4)

            if !formatsExpanded {
                Button {
                    withAnimation {
                        formatsExpanded = true
                    }
                } label: {
                    HStack {
                        Text("Show More")
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                }
            }
        } header: {
            Text("Format")
        } footer: {
            Text("Show cards legal in any of these formats.")
        }
        .onAppear {
            if !draft.formats.isDisjoint(with: Self.belowFoldFormats) {
                formatsExpanded = true
            }
        }
    }

    // MARK: - Type Section

    private static let cardTypes = [
        "Artifact", "Creature", "Enchantment", "Instant", "Land", "Legendary", "Planeswalker", "Sorcery",
    ]

    @ViewBuilder
    private var typeSection: some View {
        Section {
            FlowLayout(spacing: 8) {
                ForEach(Self.cardTypes, id: \.self) { type in
                    chipButton(type, isSelected: draft.types.contains(type)) {
                        draft.types.toggle(type)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Type")
        } footer: {
            Text("Show cards matching any of these types.")
        }
    }

    // MARK: - Rarity Section

    private static let allRarities: [(Card.Rarity, String)] = [
        (.common, "Common"),
        (.uncommon, "Uncommon"),
        (.rare, "Rare"),
        (.mythic, "Mythic"),
    ]

    @ViewBuilder
    private var raritySection: some View {
        Section {
            FlowLayout(spacing: 8) {
                ForEach(Self.allRarities, id: \.0) { rarity, label in
                    chipButton(label, isSelected: draft.rarities.contains(rarity)) {
                        draft.rarities.toggle(rarity)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Rarity")
        } footer: {
            Text("Show cards matching any of these rarities.")
        }
    }

    // MARK: - Chip Button

    private func chipButton(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct ArrangementResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> ArrangementResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + lineHeight
        }

        return ArrangementResult(
            size: CGSize(width: totalWidth, height: totalHeight),
            positions: positions
        )
    }
}

// MARK: - Set Toggle Helper

private extension Set {
    mutating func toggle(_ element: Element) {
        if contains(element) {
            remove(element)
        } else {
            insert(element)
        }
    }
}
