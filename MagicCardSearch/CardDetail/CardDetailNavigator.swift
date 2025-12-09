//
//  CardDetailView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//
import SwiftUI

struct CardDetailNavigator: View {
    let cards: [CardResult]
    let initialIndex: Int
    
    @State private var currentIndex: Int
    @State private var scrollPosition: Int?
    @Environment(\.dismiss) private var dismiss
    
    init(cards: [CardResult], initialIndex: Int) {
        self.cards = cards
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
        self._scrollPosition = State(initialValue: initialIndex)
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            CardDetailView(card: card)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .containerRelativeFrame(.horizontal)
                                .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $scrollPosition)
                .scrollIndicators(.hidden)
            }
            .navigationTitle(cards[currentIndex].name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                }
            }
            .overlay(alignment: .bottom) {
                Text("\(currentIndex + 1) of \(cards.count)")
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            scrollPosition = initialIndex
        }
        .onChange(of: scrollPosition) { _, newValue in
            if let newValue {
                currentIndex = newValue
            }
        }
    }
}

// MARK: - Preview

#Preview("Card Navigator") {
    CardDetailNavigator(
        cards: [
            CardResult(id: "1", name: "Black Lotus", imageUrl: nil),
            CardResult(id: "2", name: "Mox Ruby", imageUrl: nil),
            CardResult(id: "3", name: "Time Walk", imageUrl: nil)
        ],
        initialIndex: 0
    )
}
