//
//  CardListView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-09.
//

import SwiftUI
import ScryfallKit
import NukeUI

struct BookmarkedCardsListView: View {
    @ObservedObject var listManager = BookmarkedCardListManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .inactive
    @State private var selectedCards: Set<UUID> = []
    @State private var detailSheetState: SheetState?
    @AppStorage("bookmarkedCardsSortOption")
    private var sortOption: BookmarkedCardSortOption = .name
    
    private var isEditing: Bool {
        return editMode == .active
    }
    
    private var sortedCards: [BookmarkedCard] {
        listManager.sortedCards(by: sortOption)
    }

    var body: some View {
        NavigationStack {
            Group {
                if listManager.cards.isEmpty {
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
                        ForEach(Array(sortedCards.enumerated()), id: \.element.id) { index, card in
                            CardListRow(card: card)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !isEditing {
                                        detailSheetState = SheetState(index: index, cards: sortedCards)
                                    }
                                }
                                .tag(card.id)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            listManager.removeCard(withId: card.id)
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
                        if selectedCards.count == listManager.cards.count {
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
                                    selectedCards = Set(listManager.cards.map(\.id))
                                }
                            } label: {
                                Text("Select All")
                            }
                        }

                        Spacer()

                        Button(role: .destructive) {
                            withAnimation {
                                for cardId in selectedCards {
                                    listManager.removeCard(withId: cardId)
                                }
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
                            Picker("Sort Order", selection: $sortOption) {
                                ForEach(BookmarkedCardSortOption.allCases) { option in
                                    Label {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(option.displayName)
                                            if let subtitle = option.subtitle {
                                                Text(subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    } icon: {
                                        Image(systemName: option.systemImage)
                                    }
                                    .tag(option)
                                }
                            }
                            .pickerStyle(.inline)
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .disabled(listManager.cards.isEmpty)
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation {
                                editMode = .active
                            }
                        } label: {
                            Image(systemName: "checklist")
                        }
                        .disabled(listManager.cards.isEmpty)
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(
                            item: shareableText
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(listManager.cards.isEmpty)
                    }
                }
            }
        }
        .sheet(item: $detailSheetState) { state in
            BookmarkedCardDetailNavigator(
                cards: state.cards,
                initialIndex: state.index
            )
        }
    }
    
    // Helper struct to make sheet item identifiable
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
        sortedCards.map { "1 \($0.name) (\($0.setCode.uppercased()))" }.joined(separator: "\n")
    }
}

// MARK: - Card Detail Navigator From List

private struct BookmarkedCardDetailNavigator: View {
    let cards: [BookmarkedCard]
    let initialIndex: Int
    
    @State private var cardFlipStates: [UUID: Bool] = [:]
    @ObservedObject private var listManager = BookmarkedCardListManager.shared
    
    private let cardSearchService = CardSearchService()
    
    var body: some View {
        LazyPagingDetailNavigator(
            items: cards,
            initialIndex: initialIndex,
            totalCount: cards.count,
            hasMorePages: false,
            isLoadingNextPage: false,
            nextPageError: nil,
            loadDistance: 1,
            loader: { card in
                print("Fetching card: \(card.name) (ID: \(card.id))")
                return try await cardSearchService.fetchCard(byId: card.id)
            }
        ) { card in
            CardDetailView(
                card: card,
                isFlipped: Binding(
                    get: { cardFlipStates[card.id] ?? false },
                    set: { cardFlipStates[card.id] = $0 }
                )
            )
        } toolbarContent: { card in
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let listItem = BookmarkedCard(from: card)
                    listManager.toggleCard(listItem)
                } label: {
                    Image(
                        systemName: listManager.contains(cardWithId: card.id)
                            ? "bookmark.fill" : "bookmark"
                    )
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

private struct CardListRow: View {
    let card: BookmarkedCard

    var body: some View {
        HStack(spacing: 10) {
            // Card Image
            Group {
                if let imageUrl = card.smallImageUrl, let url = URL(string: imageUrl) {
                    LazyImage(url: url) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 84)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else if state.error != nil {
                            imagePlaceholder
                        } else {
                            ProgressView()
                                .frame(width: 60, height: 84)
                        }
                    }
                } else {
                    imagePlaceholder
                }
            }

            // Card Info
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

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.gray.opacity(0.2))
            .frame(width: 60, height: 84)
            .overlay(
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            )
    }
}

// MARK: - Preview

#Preview("With Cards") {
    BookmarkedCardsListView()
}

#Preview("Empty State") {
    BookmarkedCardsListView()
}
