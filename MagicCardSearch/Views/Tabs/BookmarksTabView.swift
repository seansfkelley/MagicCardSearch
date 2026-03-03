import SwiftUI
import ScryfallKit
import SQLiteData
import NukeUI
import GRDB
import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "BookmarksTabView")

struct BookmarksTabView: View {
    @Binding var searchState: SearchState
    @Binding var selectedTab: Tab
    @State private var editMode: EditMode = .inactive
    @State private var selectedCards: Set<UUID> = []
    @State private var detailSheetState: SheetState?

    @Environment(BookmarkedCardsStore.self) private var bookmarkedCardsStore
    @State @FetchAll private var bookmarks: [BookmarkedCard] = []
    @AppStorage("bookmarkedCardsSortOption")
    private var sortMode: BookmarkSortMode = .name

    private var isEditing: Bool {
        return editMode == .active
    }

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)

                        Text("No Cards Saved")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Tap the bookmark button on any card to add it to your saved cards.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedCards) {
                        ForEach(Array(bookmarks.enumerated()), id: \.element.id) { index, bookmark in
                            BookmarkedCardRowView(card: bookmark)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !isEditing {
                                        detailSheetState = SheetState(index: index, cards: bookmarks)
                                    }
                                }
                                .tag(bookmark.id)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            bookmarkedCardsStore.unbookmark(id: bookmark.id)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .environment(\.editMode, $editMode)
                }
            }
            .toolbarVisibility(isEditing ? .hidden : .automatic, for: .tabBar)
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .topBarLeading) {
                        if selectedCards.count == bookmarks.count {
                            Button {
                                withAnimation {
                                    selectedCards.removeAll()
                                }
                            } label: {
                                Text("Deselect All")
                            }
                        } else {
                            Button {
                                withAnimation {
                                    selectedCards = Set(bookmarks.map(\.id))
                                }
                            } label: {
                                Text("Select All")
                            }
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation {
                                editMode = .inactive
                                selectedCards.removeAll()
                            }
                        } label: {
                            Text("Done")
                        }
                    }

                    ToolbarItemGroup(placement: .bottomBar) {
                        Spacer()

                        Button(role: .destructive) {
                            withAnimation {
                                bookmarkedCardsStore.unbookmark(ids: selectedCards)
                                selectedCards.removeAll()
                                editMode = .inactive
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(selectedCards.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Picker("Sort Order", selection: $sortMode) {
                                ForEach(BookmarkSortMode.allCases) { mode in
                                    Button(action: {}) {
                                        if let subtitle = mode.subtitle {
                                            Text(mode.displayName)
                                            Text(subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text(mode.displayName)
                                        }
                                    }
                                    .tag(mode)
                                }
                            }
                            .pickerStyle(.inline)
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .disabled(bookmarks.isEmpty)
                    }

                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation {
                                editMode = .active
                            }
                        } label: {
                            Image(systemName: "checklist")
                        }
                        .disabled(bookmarks.isEmpty)
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(
                            item: shareableText
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(bookmarks.isEmpty)
                    }
                }
            }
        }
        .sheet(item: $detailSheetState) { state in
            BookmarkedCardDetailNavigator(
                initialBookmarks: state.cards,
                initialIndex: state.index,
                searchState: $searchState,
                selectedTab: $selectedTab,
            )
        }
        .task(id: sortMode) {
            _ = await withErrorReporting {
                try await $bookmarks.wrappedValue.load(ordering())
            }
        }
    }

    private func ordering() -> SelectOf<BookmarkedCard> {
        switch sortMode {
        case .name:
            BookmarkedCard.order {
                (
                    $0.name.asc(),
                    $0.setCode.asc(),
                    $0.collectorNumber.asc(),
                )
            }
        case .releaseDateNewest:
            BookmarkedCard.order {
                (
                    $0.releasedAt.desc(),
                    $0.name.asc(),
                    $0.setCode.asc(),
                    $0.collectorNumber.asc()
                )
            }
        case .releaseDateOldest:
            BookmarkedCard.order {
                (
                    $0.releasedAt.asc(),
                    $0.name.asc(),
                    $0.setCode.asc(),
                    $0.collectorNumber.asc()
                )
            }
        case .dateAddedNewest:
            BookmarkedCard.order {
                (
                    $0.bookmarkedAt.desc(),
                    $0.name.asc(),
                    $0.setCode.asc(),
                    $0.collectorNumber.asc()
                )
            }
        case .dateAddedOldest:
            BookmarkedCard.order {
                (
                    $0.bookmarkedAt.asc(),
                    $0.name.asc(),
                    $0.setCode.asc(),
                    $0.collectorNumber.asc()
                )
            }
        }
    }

    struct SheetState: Identifiable {
        let id: UUID
        let index: Int
        let cards: [BookmarkedCard]

        init(index: Int, cards: [BookmarkedCard]) {
            self.index = index
            self.cards = cards
            self.id = cards.indices.contains(index) ? cards[index].id : UUID()
        }
    }

    private var shareableText: String {
        bookmarks.map { "1 \($0.name) (\($0.setCode.uppercased()))" }.joined(separator: "\n")
    }
}

// MARK: - Card Detail Navigator From List

private struct BookmarkedCardDetailNavigator: View {
    private enum LoadingState {
        case loading(Task<Void, Never>)
        case loaded(Card)
        case failed(Error)
    }
    
    let initialBookmarks: [BookmarkedCard]
    @Binding var searchState: SearchState
    @Binding var selectedTab: Tab

    @State private var cardFlipStates: [UUID: Bool] = [:]
    @State private var scrollIndex: Int?
    @State private var loadedCards: [Card.ID: LoadingState] = [:]

    @FetchAll private var allBookmarks: [BookmarkedCard]
    @Environment(BookmarkedCardsStore.self) private var bookmarkedCardsStore
    @Environment(\.dismiss) private var dismiss
    private let cardSearchService = CardSearchService()

    init(initialBookmarks: [BookmarkedCard], initialIndex: Int, searchState: Binding<SearchState>, selectedTab: Binding<Tab>) {
        self.initialBookmarks = initialBookmarks
        self._searchState = searchState
        self._selectedTab = selectedTab
        self._scrollIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(initialBookmarks.enumerated()), id: \.element.id) { index, bookmarkedCard in
                            cardView(for: bookmarkedCard, with: geometry)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .containerRelativeFrame(.horizontal)
                                .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $scrollIndex)
                .scrollIndicators(.hidden)
            }
            .navigationTitle(initialBookmarks[safe: scrollIndex ?? -1]?.name ?? "Loading...")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }

                if let bookmarkedCard = initialBookmarks[safe: scrollIndex ?? -1] {
                    if let bookmark = allBookmarks.first(where: { $0.id == bookmarkedCard.id }) {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                bookmarkedCardsStore.unbookmark(id: bookmark.id)
                            } label: {
                                Image(systemName: "bookmark.fill")
                            }
                        }
                    } else {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                bookmarkedCardsStore.bookmark(card: bookmarkedCard)
                            } label: {
                                Image(systemName: "bookmark")
                            }
                        }
                    }

                    if let loadable = loadedCards[bookmarkedCard.id],
                       case .loaded(let card) = loadable,
                        let url = URL(string: card.scryfallUri) {
                        ToolbarItem(placement: .topBarTrailing) {
                            ShareLink(item: url)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("\((scrollIndex ?? 0) + 1) of \(initialBookmarks.count)")
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            if let scrollIndex, let card = initialBookmarks[safe: scrollIndex] {
                load(card: card)
            }
        }
        .onChange(of: scrollIndex) {
            if let scrollIndex, let card = initialBookmarks[safe: scrollIndex] {
                load(card: card)
            }
        }
        .onChange(of: initialBookmarks.count) { _, newCount in
            if let scrollIndex, scrollIndex > newCount {
                self.scrollIndex = newCount
                if let card = initialBookmarks[safe: newCount] {
                    load(card: card)
                }
            }
        }
    }

    @ViewBuilder
    private func cardView(for card: BookmarkedCard, with geometry: GeometryProxy) -> some View {
        switch loadedCards[card.id] {
        case .loaded(let card):
            CardDetailView(card: card, isFlipped: $cardFlipStates.for(card.id), searchState: $searchState)
        case .loading:
            CardPlaceholderView(name: card.name, cornerRadius: 16, with: .spinner)
        case .failed(let error):
            CardPlaceholderView(name: card.name, cornerRadius: 16, with: .error(error, { load(card: card) }))
        case nil:
            CardPlaceholderView(name: card.name, cornerRadius: 16, with: .spinner)
                .onAppear {
                    // This really shouldn't happen, but I guess just in case...
                    load(card: card)
                }
        }
    }

    private func load(card: BookmarkedCard) {
        switch loadedCards[card.id] {
        case .loaded, .loading:
            return
        default:
            break
        }

        let task = Task {
            do {
                logger.info("fetching card cardName=\(card.name) cardId=\(card.id)")
                let loadedCard = try await cardSearchService.fetchCard(byScryfallId: card.id)

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    loadedCards[card.id] = .loaded(loadedCard)
                }
            } catch is CancellationError {
                // nop
            } catch {
                await MainActor.run {
                    loadedCards[card.id] = .failed(error)
                }
            }
        }

        loadedCards[card.id] = .loading(task)
    }
}

// MARK: - Card List Row

private struct BookmarkedCardRowView: View {
    let card: BookmarkedCard

    var body: some View {
        HStack(spacing: 10) {
            CardView(
                card: card,
                quality: .small,
                isFlipped: .constant(false),
                cornerRadius: 6,
                showFlipButton: false
            )
            .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)

                if let typeLine = card.typeLine {
                    Text(typeLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    SetIconView(setCode: SetCode(card.setCode), size: 12)
                    Text(card.setCode.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("#\(card.collectorNumber)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(card.setName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}
