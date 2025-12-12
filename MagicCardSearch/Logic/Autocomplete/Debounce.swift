//
//  Debounce.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-12.
//
import SwiftUI
import ScryfallKit

// All of this pulled straight from
// https://livsycode.com/swiftui/how-to-use-debounce-in-swiftui-or-in-observable-classes/
actor Debounce<each Parameter: Sendable, T: Sendable> {
    private let action: @Sendable (repeat each Parameter) async -> T
    private let delay: Duration
    private var task: Task<T?, Never>?
    
    init(
        _ action: @Sendable @escaping (repeat each Parameter) async -> T,
        for dueTime: Duration
    ) {
        delay = dueTime
        self.action = action
    }
}

extension Debounce {
    func callAsFunction(_ parameter: repeat each Parameter) {
        task?.cancel()
        
        task = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return nil }
            return await action(repeat each parameter)
        }
    }
    
    func cancel() {
        task?.cancel()
        task = nil
    }
}

private struct DebounceModifier<Value: Equatable>: ViewModifier {
    typealias Completion = (Value, Value) -> Void
    typealias TaskType = Task<Void, Never>
    
    private let value: Value
    private let delay: Duration
    private let initial: Bool
    private let action: Completion
    
    @Binding private var parentTask: TaskType?
    @State private var internalTask: TaskType?
    @State private var useParentTask: Bool
    
    private var currentTask: Binding<TaskType?> {
        Binding<TaskType?>(
            get: {
                if useParentTask { parentTask } else { internalTask }
            },
            set: {
                if useParentTask { parentTask = $0 } else { internalTask = $0 }
            }
        )
    }
    
    init(
        value: Value,
        for dueTime: Duration,
        task: Binding<TaskType?>?,
        initial: Bool,
        action: @escaping Completion
    ) {
        self.value = value
        delay = dueTime
        self.initial = initial
        self.action = action
        
        if let task {
            _parentTask = task
            useParentTask = true
        } else {
            _parentTask = .constant(nil)
            useParentTask = false
        }
    }
    
    func body(content: Content) -> some View {
        content.onChange(
            of: value,
            initial: initial
        ) { oldValue, newValue in
            currentTask.wrappedValue?.cancel()
            currentTask.wrappedValue = Task {
                try? await Task.sleep(for: delay)
                
                guard !Task.isCancelled else { return }
                
                action(oldValue, newValue)
                currentTask.wrappedValue = nil
            }
        }
    }
}

extension View {
    func onChangeDebounced<Value: Equatable>(
        of value: Value,
        for dueTime: Duration,
        task: Binding<Task<Void, Never>?>? = nil,
        initial: Bool = false,
        _ action: @escaping (_ oldValue: Value, _ newValue: Value) -> Void
    ) -> some View {
        modifier(
            DebounceModifier(
                value: value,
                for: dueTime,
                task: task,
                initial: initial,
                action: action
            )
        )
    }
}
