//
//  CardListView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-09.
//

import SwiftUI
import ScryfallKit
import NukeUI

struct SavedCardsListView: View {
    @ObservedObject var listManager = CardListManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .inactive
    @State private var selectedCards: Set<UUID> = []
    @State private var detailSheetState: SheetState?
    
    private var isEditing: Bool {
        return editMode == .active
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
                        ForEach(Array(listManager.sortedCards.enumerated()), id: \.element.id) { index, card in
                            CardListRow(card: card)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !isEditing {
                                        detailSheetState = SheetState(index: index, cards: listManager.sortedCards)
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
            .navigationTitle("Saved Cards")
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
                                    selectedCards = Set(listManager.sortedCards.map(\.id))
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
            CardDetailNavigatorFromList(
                cards: state.cards,
                initialIndex: state.index
            )
        }
    }
    
    // Helper struct to make sheet item identifiable
    struct SheetState: Identifiable {
        let id: UUID
        let index: Int
        let cards: [CardListItem]
        
        init(index: Int, cards: [CardListItem]) {
            self.index = index
            self.cards = cards
            // Use the card ID at this index as a stable identifier
            self.id = cards.indices.contains(index) ? cards[index].id : UUID()
        }
    }

    // MARK: - Shareable Text

    private var shareableText: String {
        listManager.sortedCards.map { "1 \($0.name) (\($0.setCode.uppercased())" }.joined(separator: "\n")
    }
}

// MARK: - Card Detail Navigator From List

private struct CardDetailNavigatorFromList: View {
    let cards: [CardListItem]
    let initialIndex: Int
    
    @State private var fullCards: [Card] = []
    @State private var isLoading = true
    @State private var error: Error?
    @Environment(\.dismiss) private var dismiss
    @State private var cardFlipStates: [UUID: Bool] = [:]
    
    private let cardSearchService = CardSearchService()
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading card details...")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    
                    Text("Failed to load card details")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(error.localizedDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Button("Try Again") {
                        Task {
                            await loadCards()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !fullCards.isEmpty {
                CardDetailNavigator(
                    cards: fullCards,
                    initialIndex: initialIndex,
                    totalCount: fullCards.count,
                    cardFlipStates: $cardFlipStates,
                )
            } else {
                Text("No cards to display")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await loadCards()
        }
    }
    
    private func loadCards() async {
        isLoading = true
        error = nil
        
        print("Loading \(cards.count) cards from list...")
        
        do {
            // Fetch full card details for all cards in the list
            var loadedCards: [Card] = []
            for card in cards {
                print("Fetching card: \(card.name) (ID: \(card.id))")
                let fullCard = try await cardSearchService.fetchCard(byId: card.id)
                loadedCards.append(fullCard)
            }
            fullCards = loadedCards
            print("Successfully loaded \(fullCards.count) cards")
        } catch {
            print("Error loading cards: \(error)")
            self.error = error
        }
        
        isLoading = false
    }
}

// MARK: - Card List Row

private struct CardListRow: View {
    let card: CardListItem

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
                    SetIconView(setCode: card.setCode, size: 12)
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
    SavedCardsListView()
}

#Preview("Empty State") {
    SavedCardsListView()
}
