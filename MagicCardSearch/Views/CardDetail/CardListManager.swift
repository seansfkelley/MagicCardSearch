//
//  CardListManager.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-09.
//

import Foundation

@MainActor
class CardListManager: ObservableObject {
    static let shared = CardListManager()
    
    @Published private(set) var cards: [CardListItem] = [] {
        didSet {
            _cardIdsCache = nil
        }
    }
    
    private let fileURL: URL
    private var _cardIdsCache: Set<UUID>?
    
    private init() {
        // Set up the file URL in the documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("cardList.json")
        
        // Load existing cards from disk
        loadCards()
    }
    
    // MARK: - Private Computed Properties
    
    /// Memoized set of card IDs for fast containment checks
    private var cardIds: Set<UUID> {
        if let cached = _cardIdsCache {
            return cached
        }
        let ids = Set(cards.map(\.id))
        _cardIdsCache = ids
        return ids
    }
    
    // MARK: - Public Methods
    
    func addCard(_ card: CardListItem) {
        guard !contains(cardWithId: card.id) else { return }
        
        cards.append(card)
        saveCards()
    }
    
    func removeCard(withId id: UUID) {
        cards.removeAll { $0.id == id }
        saveCards()
    }
    
    func toggleCard(_ card: CardListItem) {
        if contains(cardWithId: card.id) {
            removeCard(withId: card.id)
        } else {
            addCard(card)
        }
    }
    
    func contains(cardWithId cardId: UUID) -> Bool {
        cardIds.contains(cardId)
    }
    
    var sortedCards: [CardListItem] {
        cards.sorted()
    }
    
    func clearAll() {
        cards.removeAll()
        saveCards()
    }
    
    // MARK: - Persistence
    
    private func loadCards() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // No saved file yet
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            cards = try JSONDecoder().decode([CardListItem].self, from: data)
        } catch {
            print("Error loading card list: \(error)")
            cards = []
        }
    }
    
    private func saveCards() {
        do {
            let data = try JSONEncoder().encode(cards)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("Error saving card list: \(error)")
        }
    }
}
