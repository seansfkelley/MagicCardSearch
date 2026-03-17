import SwiftUI
import ScryfallKit
import SQLiteData
import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "BookmarkedCardListView")

struct BookmarkedCardListView: View {
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
            FixedListCardDetailNavigatorView(
                cards: state.cards,
                initialIndex: state.index,
                searchState: nil
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
