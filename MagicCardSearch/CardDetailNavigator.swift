//
//  CardDetailView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import SwiftUI

// MARK: - Card Detail Navigator

struct CardDetailNavigator: View {
    let cards: [CardResult]
    let initialIndex: Int
    
    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    init(cards: [CardResult], initialIndex: Int) {
        self.cards = cards
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        NavigationStack {
            TabView(selection: $currentIndex) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    CardDetailView(card: card)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .navigationTitle(cards[currentIndex].name)
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottom) {
                Text("\(currentIndex + 1) of \(cards.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Preview

#Preview("Single Card") {
    CardDetailNavigator(
        cards: [
            CardResult(id: "1", name: "Black Lotus", imageUrl: nil),
            CardResult(id: "2", name: "Mox Ruby", imageUrl: nil),
            CardResult(id: "3", name: "Time Walk", imageUrl: nil)
        ],
        initialIndex: 0
    )
}

#Preview("Card Detail Only") {
    CardDetailView(
        card: CardResult(
            id: "preview-id",
            name: "Black Lotus",
            imageUrl: nil
        )
    )
}
