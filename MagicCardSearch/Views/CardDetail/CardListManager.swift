//
//  CardListManager.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-09.
//

import Foundation

/// A singleton manager for the user's saved card list with disk persistence
@MainActor
class CardListManager: ObservableObject {
    static let shared = CardListManager()
    
    @Published private(set) var cards: [CardListItem] = []
    
    private let fileURL: URL
    
    private init() {
        // Set up the file URL in the documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("cardList.json")
        
        // Load existing cards from disk
        loadCards()
    }
    
    // MARK: - Public Methods
    
    /// Add a card to the list
    func addCard(_ card: CardListItem) {
        // Don't add duplicates
        guard !cards.contains(where: { $0.id == card.id }) else { return }
        
        cards.append(card)
        saveCards()
    }
    
    /// Remove a card from the list by ID
    func removeCard(withId id: String) {
        cards.removeAll { $0.id == id }
        saveCards()
    }
    
    /// Toggle a card's presence in the list
    func toggleCard(_ card: CardListItem) {
        if contains(cardId: card.id) {
            removeCard(withId: card.id)
        } else {
            addCard(card)
        }
    }
    
    /// Check if a card is in the list
    func contains(cardId: String) -> Bool {
        cards.contains { $0.id == cardId }
    }
    
    /// Get sorted cards (alphabetically by name, then by release date)
    var sortedCards: [CardListItem] {
        cards.sorted()
    }
    
    /// Clear all cards from the list
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
