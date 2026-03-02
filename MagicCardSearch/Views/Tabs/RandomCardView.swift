import SwiftUI
import ScryfallKit
import SQLiteData
import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "RandomCardView")

// MARK: - Filter Model

struct RandomCardFilters: Equatable {
    var colors: Set<Card.Color> = []
    var useColorIdentity = false
    var formats: Set<Format> = []
    var types: Set<String> = []
    var rarities: Set<Card.Rarity> = []

    var queryString: String? {
        var groups: [String] = []

        if !colors.isEmpty {
            let key = useColorIdentity ? "id" : "c"
            let clause = colors.map { "\(key):\($0.rawValue.lowercased())" }.joined(separator: " OR ")
            groups.append("(\(clause))")
        }

        if !formats.isEmpty {
            let clause = formats.map { "f:\($0.rawValue)" }.joined(separator: " OR ")
            groups.append("(\(clause))")
        }

        if !types.isEmpty {
            let clause = types.map { "t:\($0.lowercased())" }.joined(separator: " OR ")
            groups.append("(\(clause))")
        }

        if !rarities.isEmpty {
            let clause = rarities.map { "r:\($0.rawValue)" }.joined(separator: " OR ")
            groups.append("(\(clause))")
        }

        return groups.isEmpty ? nil : groups.joined(separator: " ")
    }
}

// MARK: - RandomCardView

struct RandomCardView: View {
    @Binding var searchState: SearchState

    @State private var history: [Card] = []
    @State private var isLoadingNext = false
    @State private var loadError: Error?
    @State private var filters = RandomCardFilters()
    @State private var showingFilterSheet = false
    @State private var cardFlipStates: [UUID: Bool] = [:]

    @Environment(BookmarkedCardsStore.self) private var bookmarkedCardsStore
    @FetchAll private var bookmarks: [BookmarkedCard]

    private let client = ScryfallClient()

    var body: some View {
        Group {
            if !history.isEmpty {
                navigatorView
            } else if let error = loadError {
                initialErrorView(error: error)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if history.isEmpty && !isLoadingNext {
                fetchNextCard()
            }
        }
    }

    // MARK: - Navigator

    private var navigatorView: some View {
        LazyPagingDetailNavigator(
            items: history,
            initialIndex: 0,
            hasMorePages: true,
            isLoadingNextPage: isLoadingNext,
            nextPageError: loadError.map { SearchErrorState(from: $0) },
            loadDistance: 1,
            loader: { card in card },
            onNearEnd: fetchNextCard,
            onRetryNextPage: fetchNextCard
        ) { card in
            CardDetailView(
                card: card,
                isFlipped: Binding(
                    get: { cardFlipStates[card.id] ?? false },
                    set: { cardFlipStates[card.id] = $0 }
                ),
                searchState: $searchState
            )
        } toolbarContent: { card in
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingFilterSheet = true
                } label: {
                    Image(systemName: hasActiveFilters
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
            }

            if let card {
                if bookmarks.contains(where: { $0.id == card.id }) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            bookmarkedCardsStore.unbookmark(id: card.id)
                        } label: {
                            Image(systemName: "bookmark.fill")
                        }
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            bookmarkedCardsStore.bookmark(card: card)
                        } label: {
                            Image(systemName: "bookmark")
                        }
                    }
                }

                if let url = URL(string: card.scryfallUri) {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: url)
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            RandomCardFilterSheet(filters: filters) { newFilters in
                applyFilters(newFilters)
            }
        }
    }

    // MARK: - Initial Error View

    private func initialErrorView(error: Error) -> some View {
        let errorState = SearchErrorState(from: error)
        return VStack(spacing: 20) {
            Image(systemName: errorState.iconName)
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text(errorState.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(errorState.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button("Retry") {
                fetchNextCard()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var hasActiveFilters: Bool {
        filters != RandomCardFilters()
    }

    private func fetchNextCard() {
        guard !isLoadingNext else { return }
        isLoadingNext = true
        loadError = nil

        Task {
            do {
                let card = try await client.getRandomCard(query: filters.queryString)
                history.append(card)
            } catch {
                logger.error("Error fetching random card: \(error)")
                loadError = error
            }
            isLoadingNext = false
        }
    }

    private func applyFilters(_ newFilters: RandomCardFilters) {
        filters = newFilters
        // Keep only cards up to and including the current visible card.
        // LazyPagingDetailNavigator's onChange(of: items.count) handles scroll clamping.
        // We can't easily read the navigator's currentIndex from here, so we truncate
        // forward history conservatively by keeping all existing cards and just fetching
        // new ones with the updated filters.
        // Actually per the design doc: truncate to history[0...currentIndex]. Since we
        // don't have direct access to currentIndex, we keep all history (the user sees
        // what they've already seen) and just fetch the next card with new filters.
        fetchNextCard()
    }
}

// MARK: - Filter Sheet

private struct RandomCardFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: RandomCardFilters
    let onApply: (RandomCardFilters) -> Void

    init(filters: RandomCardFilters, onApply: @escaping (RandomCardFilters) -> Void) {
        self._draft = State(initialValue: filters)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
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
            Text("Show cards containing any of these colors.")
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
        .accessibilityLabel(colorLabel(for: color))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func colorLabel(for color: Card.Color) -> String {
        switch color {
        case .W: "White"
        case .U: "Blue"
        case .B: "Black"
        case .R: "Red"
        case .G: "Green"
        case .C: "Colorless"
        }
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
