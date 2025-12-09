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
    let totalCount: Int
    let hasMorePages: Bool
    let isLoadingNextPage: Bool
    let nextPageError: SearchErrorState?
    var onNearEnd: (() -> Void)?
    var onRetryNextPage: (() -> Void)?
    
    @State private var currentIndex: Int
    @State private var scrollPosition: Int?
    @Environment(\.dismiss) private var dismiss
    
    init(cards: [CardResult], 
         initialIndex: Int,
         totalCount: Int = 0,
         hasMorePages: Bool = false,
         isLoadingNextPage: Bool = false,
         nextPageError: SearchErrorState? = nil,
         onNearEnd: (() -> Void)? = nil,
         onRetryNextPage: (() -> Void)? = nil) {
        self.cards = cards
        self.initialIndex = initialIndex
        self.totalCount = totalCount
        self.hasMorePages = hasMorePages
        self.isLoadingNextPage = isLoadingNextPage
        self.nextPageError = nextPageError
        self.onNearEnd = onNearEnd
        self.onRetryNextPage = onRetryNextPage
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
                        
                        // Show pagination status page if there are more pages or loading/error
                        if hasMorePages || isLoadingNextPage || nextPageError != nil {
                            paginationStatusPage(geometry: geometry)
                                .id(-1) // Special ID for pagination page
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $scrollPosition)
                .scrollIndicators(.hidden)
            }
            .navigationTitle(navigationTitle)
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
                Text(counterText)
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
                
                // Trigger pagination when within 3 items of the end
                if newValue >= cards.count - 3 {
                    onNearEnd?()
                }
            }
        }
    }
    
    private var navigationTitle: String {
        if currentIndex >= 0 && currentIndex < cards.count {
            return cards[currentIndex].name
        } else {
            return "Loading..."
        }
    }
    
    private var counterText: String {
        if currentIndex >= 0 && currentIndex < cards.count {
            return "\(currentIndex + 1) of \(totalCount > 0 ? totalCount : cards.count)"
        } else {
            return "Loading more..."
        }
    }
    
    @ViewBuilder
    private func paginationStatusPage(geometry: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            if isLoadingNextPage {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading more cards...")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            } else if let error = nextPageError {
                VStack(spacing: 20) {
                    Image(systemName: error.iconName)
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 8) {
                        Text(error.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(error.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    Button("Retry") {
                        onRetryNextPage?()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else {
                // This case shouldn't happen, but show loading as fallback
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading more cards...")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .containerRelativeFrame(.horizontal)
    }
}
