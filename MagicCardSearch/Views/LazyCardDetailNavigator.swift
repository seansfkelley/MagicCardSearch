import SwiftUI
import ScryfallKit

protocol Nameable {
    var name: String { get }
}

// MARK: - Conformances

extension Card: Nameable {}
extension BookmarkedCard: Nameable {}

struct LazyCardDetailNavigator<
    CardReference: Nameable & Identifiable,
    Toolbar: ToolbarContent,
    BottomContent: View,
>: View where CardReference.ID == Card.ID {
    // MARK: - Types
    
    private enum LoadingState {
        case loading(Task<Void, Never>)
        case loaded(Card)
        case failed(Error)
    }
    
    // MARK: - Properties
    
    let references: [CardReference]
    @Binding var cardFlipStates: [UUID: Bool]
    @Binding var searchState: SearchState
    let loader: (CardReference) async throws -> Card
    let toolbarContent: (Card?) -> Toolbar
    let bottomContent: (() -> BottomContent?)? = nil

    @State private var loadedCards: [Card.ID: LoadingState] = [:]
    @Binding private var scrollIndex: Int?

    private let preloadDistance = 1

    // MARK: - Initialization
    
    init(
        _ references: [CardReference],
        scrollIndex: Binding<Int?>,
        cardFlipStates: Binding<[UUID: Bool]>,
        searchState: Binding<SearchState>,
        loader: @escaping (CardReference) async throws -> Card,
        @ToolbarContentBuilder toolbarContent: @escaping (Card?) -> Toolbar,
        @ViewBuilder bottomContent: @escaping () -> BottomContent?
    ) {
        self.references = references
        self._scrollIndex = scrollIndex
        self._cardFlipStates = cardFlipStates
        self._searchState = searchState
        self.loader = loader
        self.toolbarContent = toolbarContent
        self.bottomContent = bottomContent
    }
    
    init(
        _ references: [CardReference],
        scrollIndex: Binding<Int?>,
        cardFlipStates: Binding<[UUID: Bool]>,
        searchState: Binding<SearchState>,
        loader: @escaping (CardReference) async throws -> Card,
        @ToolbarContentBuilder toolbarContent: @escaping (Card?) -> Toolbar,
    ) where BottomContent == EmptyView {
        self.references = references
        self._scrollIndex = scrollIndex
        self._cardFlipStates = cardFlipStates
        self._searchState = searchState
        self.loader = loader
        self.toolbarContent = toolbarContent
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(references.enumerated()), id: \.element.id) { index, itemRef in
                            itemView(at: index, itemRef: itemRef, geometry: geometry)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .containerRelativeFrame(.horizontal)
                                .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: scrollIndex)
                .scrollIndicators(.hidden)
            }
            .navigationTitle(references[safe: scrollIndex ?? -1]?.name ?? "Loading...")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let ref = references[safe: scrollIndex ?? -1], case .loaded(let card) = loadedCards[ref] {
                    toolbarContent(card)
                } else {
                    toolbarContent(nil)
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomContent?()
            }
        }
        .onAppear {
            loadCardsInWindow()
        }
        .onChange(of: scrollPosition) {
            loadCardsInWindow()
        }
        .onChange(of: references.count) { _, newCount in
            if let scrollIndex, scrollIndex > newCount {
                scrollPosition = newCount
                loadCardsInWindow()
            }
        }
    }
    
    // MARK: - Item View
    
    @ViewBuilder
    private func itemView(at index: Int, geometry: GeometryProxy) -> some View {
        guard let ref = references[safe: index] else { return EmptyView() }

        return switch loadedCards[ref.id] {
        case .loaded(let card):
            CardDetailView(card: card, isFlipped: $cardFlipStates.for(card.id), searchState: $searchState)
        case .loading:
            CardPlaceholderView(name: ref.name, cornerRadius: 16, withSpinner: true)
        case .failed(let error):
            // TODO: use CardPlaceholderView?
            errorView(for: ref.name, error: error) {
                loadCard(at: index)
            }
        case nil:
            CardPlaceholderView(name: ref.name, cornerRadius: 16, withSpinner: true)
                .onAppear {
                    // This really shouldn't happen, but I guess just in case...
                    loadCard(at: index)
                }
        }
    }
    
    @ViewBuilder
    private func errorView(for name: String, error: Error, retry: @escaping () -> Void) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("Failed to load \(name)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button("Retry") {
                retry()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Loading Logic
    
    private func loadCardsInWindow() {
        guard let scrollIndex else { return }

        let start = max(0, scrollIndex - preloadDistance)
        let end = min(references.count - 1, scrollIndex + preloadDistance)

        for index in start...end {
            let ref = references[index]
            if loadedCards[ref.id] == nil {
                loadCard(at: index)
            }
        }

        for ref in references[..<start] + references[(end + 1)...] {
            if case .loading(let task) = loadedCards[ref.id] {
                task.cancel()
                MainActor.run {
                    loadedCards.removeValue(forKey: ref.id)
                }
            }
        }
    }
    
    private func loadCard(at index: Int) {
        guard let ref = references[safe: index] else { return }

        switch loadedCards[ref.id] {
        case .loaded, .loading:
            return
        default:
            break
        }
        
        let task = Task {
            do {
                let item = try await loader(ref)

                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    loadedCards[ref.id] = .loaded(item)
                }
            } catch is CancellationError {
                // nop
            } catch {
                await MainActor.run {
                    loadedCards[ref.id] = .failed(error)
                }
            }
        }
        
        loadedCards[ref.id] = .loading(task)
    }
}
