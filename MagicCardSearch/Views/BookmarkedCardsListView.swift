import SwiftUI
import ScryfallKit
import SQLiteData
import NukeUI
import GRDB
import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "BookmarkedCardsListView")

struct BookmarkedCardsListView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var searchState: SearchState
    @State private var editMode: EditMode = .inactive
    @State private var selectedCards: Set<UUID> = []
    @State private var detailSheetState: SheetState?
    
    @Environment(BookmarkedCardsStore.self) private var bookmarkedCardsStore
    @State @FetchAll private var bookmarks: [BookmarkedCard] = [] // Needs a default because of @State.
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
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                if isEditing {
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
                    ToolbarItem(placement: .topBarTrailing) {
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
                    
                    ToolbarItem(placement: .topBarTrailing) {
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
            )
        }
        .task(id: sortMode) {
            _ = await withErrorReporting {
                try await $bookmarks.wrappedValue.load(ordering())
            }
        }
    }

    // This was the only way to appease the compiler.
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
            // Use the card ID at this index as a stable identifier
            self.id = cards.indices.contains(index) ? cards[index].id : UUID()
        }
    }

    // MARK: - Shareable Text

    private var shareableText: String {
        bookmarks.map { "1 \($0.name) (\($0.setCode.uppercased()))" }.joined(separator: "\n")
    }
}

// MARK: - Card Detail Navigator From List

private struct BookmarkedCardDetailNavigator: View {
    let initialBookmarks: [BookmarkedCard]
    let initialIndex: Int
    @Binding var searchState: SearchState

    @State private var cardFlipStates: [UUID: Bool] = [:]

    @FetchAll private var allBookmarks: [BookmarkedCard]
    @Environment(BookmarkedCardsStore.self) private var bookmarkedCardsStore
    private let cardSearchService = CardSearchService()
    
    var body: some View {
        LazyPagingDetailNavigator(
            items: initialBookmarks,
            initialIndex: initialIndex,
            totalCount: initialBookmarks.count,
            hasMorePages: false,
            isLoadingNextPage: false,
            nextPageError: nil,
            loadDistance: 1,
            loader: { card in
                logger.info("fetching card cardName=\(card.name) cardId=\(card.id)")
                return try await cardSearchService.fetchCard(byScryfallId: card.id)
            }
        ) { card in
            CardDetailView(
                card: card,
                isFlipped: Binding(
                    get: { cardFlipStates[card.id] ?? false },
                    set: { cardFlipStates[card.id] = $0 }
                ),
                searchState: $searchState,
            )
        } toolbarContent: { card in
            // n.b. we have to use allBookmarks here, not initialBookmarks, so we are reactive to
            // any changes that this detail view causes.
            if let bookmark = allBookmarks.first(where: { $0.id == card.id }) {
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
