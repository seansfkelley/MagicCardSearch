//
//  CardResultsView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import SwiftUI

struct CardResultsView: View {
    @Binding var filters: [SearchFilter]
    @State private var results: [CardResult] = []
    @State private var isLoading = false
    @State private var selectedCardIndex: Int?
    
    private let service = CardSearchService()
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        Group {
            if isLoading && results.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Add search filters to find cards")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, card in
                            CardResultCell(card: card)
                                .onTapGesture {
                                    selectedCardIndex = index
                                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 60)
                    .padding(.bottom, 20)
                }
            }
        }
        .onChange(of: filters) { _, _ in
            performSearch()
        }
        .task {
            performSearch()
        }
        .sheet(item: Binding(
            get: { selectedCardIndex.map { SheetIdentifier(index: $0) } },
            set: { selectedCardIndex = $0?.index }
        )) { identifier in
            CardDetailNavigator(
                cards: results,
                initialIndex: identifier.index
            )
        }
    }
    
    private func performSearch() {
        guard !filters.isEmpty else {
            results = []
            return
        }
        
        isLoading = true
        
        Task {
            do {
                results = try await service.search(filters: filters)
            } catch {
                print("Search error: \(error)")
                results = []
            }
            isLoading = false
        }
    }
}

// MARK: - Sheet Identifier

private struct SheetIdentifier: Identifiable {
    let index: Int
    var id: Int { index }
}

// MARK: - Card Result Cell

struct CardResultCell: View {
    let card: CardResult
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(0.7, contentMode: .fit)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        
                        Text(card.name)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .padding(8)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var filters: [SearchFilter] = [
            SearchFilter("set", .equal, "7ED"),
            SearchFilter("manavalue", .greaterThanOrEqual, "4")
        ]
        
        var body: some View {
            CardResultsView(filters: $filters)
        }
    }
    
    return PreviewWrapper()
}
