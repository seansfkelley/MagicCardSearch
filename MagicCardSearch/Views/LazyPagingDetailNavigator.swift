//
//  LazyLoadingDetailNavigator.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-16.
//

import SwiftUI
import ScryfallKit

protocol Nameable: Identifiable {
    var name: String { get }
}

// MARK: - Card Conformance

extension Card: Nameable {}

/// A generic lazy-loading detail navigator that supports paging through items with automatic loading
/// of items within a specified range of the current position.
struct LazyPagingDetailNavigator<ItemReference: Nameable, Item: Identifiable, Content: View, Toolbar: ToolbarContent>: View where ItemReference.ID == Item.ID {
    // MARK: - Types
    
    /// Represents an item that can be in various loading states
    enum LoadingState {
        case unloaded
        case loading(Task<Void, Never>)
        case loaded(Item)
        case failed(Error)
    }
    
    // MARK: - Properties
    
    let items: [ItemReference]
    let initialIndex: Int
    let totalCount: Int
    let hasMorePages: Bool
    let isLoadingNextPage: Bool
    let nextPageError: SearchErrorState?
    let loadDistance: Int
    let loader: (ItemReference) async throws -> Item
    let content: (Item) -> Content
    let toolbarContent: ((Item) -> Toolbar)?
    var onNearEnd: (() -> Void)?
    var onRetryNextPage: (() -> Void)?
    
    @State private var loadedItems: [Item.ID: LoadingState] = [:]
    @State private var currentIndex: Int
    @State private var scrollPosition: Int?
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Initialization
    
    init(
        items: [ItemReference],
        initialIndex: Int,
        totalCount: Int = 0,
        hasMorePages: Bool = false,
        isLoadingNextPage: Bool = false,
        nextPageError: SearchErrorState? = nil,
        loadDistance: Int = 1,
        loader: @escaping (ItemReference) async throws -> Item,
        onNearEnd: (() -> Void)? = nil,
        onRetryNextPage: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content,
        @ToolbarContentBuilder toolbarContent: @escaping (Item) -> Toolbar
    ) {
        self.items = items
        self.initialIndex = initialIndex
        self.totalCount = totalCount
        self.hasMorePages = hasMorePages
        self.isLoadingNextPage = isLoadingNextPage
        self.nextPageError = nextPageError
        self.loadDistance = loadDistance
        self.loader = loader
        self.content = content
        self.toolbarContent = toolbarContent
        self.onNearEnd = onNearEnd
        self.onRetryNextPage = onRetryNextPage
        self._currentIndex = State(initialValue: initialIndex)
        self._scrollPosition = State(initialValue: initialIndex)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, itemRef in
                            itemView(at: index, itemRef: itemRef, geometry: geometry)
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
                    }
                }
                
                // Add item-specific toolbar content for the current item
                if let toolbarContent = toolbarContent,
                   currentIndex >= 0,
                   currentIndex < items.count,
                   let itemRef = items[safe: currentIndex],
                   case .loaded(let item) = loadedItems[itemRef.id] {
                    toolbarContent(item)
                }
            }
            .safeAreaInset(edge: .bottom) {
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
            updateLoadingWindow()
        }
        .onChange(of: scrollPosition) { _, newValue in
            if let newValue {
                currentIndex = newValue
                updateLoadingWindow()
                
                // Trigger onNearEnd callback if approaching the end
                if newValue >= items.count - 3 {
                    onNearEnd?()
                }
            }
        }
    }
    
    // MARK: - Item View
    
    @ViewBuilder
    private func itemView(at index: Int, itemRef: ItemReference, geometry: GeometryProxy) -> some View {
        let state = loadedItems[itemRef.id] ?? .unloaded
        
        switch state {
        case .loaded(let item):
            content(item)
        case .loading:
            loadingView(for: itemRef.name)
        case .failed(let error):
            errorView(for: itemRef.name, error: error) {
                loadItem(at: index, itemRef: itemRef)
            }
        case .unloaded:
            loadingView(for: itemRef.name)
                .onAppear {
                    // This should rarely happen since updateLoadingWindow should handle it
                    loadItem(at: index, itemRef: itemRef)
                }
        }
    }
    
    @ViewBuilder
    private func loadingView(for name: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading \(name)...")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    
    // MARK: - Pagination Status Page
    
    @ViewBuilder
    private func paginationStatusPage(geometry: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            if isLoadingNextPage {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading more results...")
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
                    Text("Loading more results...")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .containerRelativeFrame(.horizontal)
    }
    
    // MARK: - Navigation Title and Counter
    
    private var navigationTitle: String {
        if currentIndex >= 0 && currentIndex < items.count {
            let itemRef = items[currentIndex]
            if case .loaded = loadedItems[itemRef.id] {
                // If we have access to the loaded item, we could potentially show more info
                // For now, just use the display name
                return itemRef.name
            }
            return itemRef.name
        } else {
            return "Loading..."
        }
    }
    
    private var counterText: String {
        if currentIndex >= 0 && currentIndex < items.count {
            return "\(currentIndex + 1) of \(totalCount > 0 ? totalCount : items.count)"
        } else {
            return "Loading more..."
        }
    }
    
    // MARK: - Loading Logic
    
    private func updateLoadingWindow() {
        let start = max(0, currentIndex - loadDistance)
        let end = min(items.count - 1, currentIndex + loadDistance)
        
        // Load items within the window
        for index in start...end {
            let itemRef = items[index]
            if loadedItems[itemRef.id] == nil {
                loadItem(at: index, itemRef: itemRef)
            }
        }
        
        // Cancel loading for items outside the window
        for (index, itemRef) in items.enumerated() {
            if index < start || index > end {
                if case .loading(let task) = loadedItems[itemRef.id] {
                    task.cancel()
                    loadedItems[itemRef.id] = .unloaded
                }
            }
        }
    }
    
    private func loadItem(at index: Int, itemRef: ItemReference) {
        // Don't reload if already loading or loaded
        switch loadedItems[itemRef.id] {
        case .loaded, .loading:
            return
        default:
            break
        }
        
        let task = Task {
            do {
                let item = try await loader(itemRef)
                
                // Only update state if task wasn't cancelled
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    loadedItems[itemRef.id] = .loaded(item)
                }
            } catch is CancellationError {
                // Task was cancelled, don't update state
                return
            } catch {
                await MainActor.run {
                    loadedItems[itemRef.id] = .failed(error)
                }
            }
        }
        
        loadedItems[itemRef.id] = .loading(task)
    }
}

// MARK: - LoadingState Equatable

extension LazyPagingDetailNavigator.LoadingState: Equatable where Item: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.unloaded, .unloaded):
            return true
        case (.loading, .loading):
            return true // We consider all loading states equal
        case (.loaded(let lhsItem), .loaded(let rhsItem)):
            return lhsItem == rhsItem
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}
