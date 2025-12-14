//
//  DebouncedLoadingState.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-14.
//

import Foundation

struct LoadingState {
    let id: UUID
    let task: Task<Void, Never>
}

@MainActor
@Observable
final class DebouncedLoadingState {
    var isLoading: Bool = false
    var isLoadingDebounced: Bool = false
    
    private var state: LoadingState?
    private let debounceDuration: Duration
    
    init(debounceDuration: Duration = .milliseconds(100)) {
        self.debounceDuration = debounceDuration
    }
    
    func start() -> UUID {
        if let state {
            state.task.cancel()
        }
        
        let id = UUID()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            
            try? await Task.sleep(for: debounceDuration)
            
            guard !Task.isCancelled else { return }
            
            isLoadingDebounced = true
        }
        
        isLoading = true
        state = .init(id: id, task: task)
        
        return id
    }
    
    func isStillCurrent(id: UUID) -> Bool {
        if let state {
            state.id == id
        } else {
            false
        }
    }
    
    func stop(for id: UUID) {
        guard let state, state.id == id else { return }
        
        state.task.cancel()
        self.state = nil
        
        isLoading = false
        isLoadingDebounced = false
    }
    
    @MainActor
    deinit {
        guard let state else { return }
        
        state.task.cancel()
    }
}
