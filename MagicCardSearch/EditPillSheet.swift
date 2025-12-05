//
//  EditPillSheet.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI

struct EditPillSheet: View {
    let filter: SearchFilter
    let onUpdate: (SearchFilter) -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    // Generic state for all filter types
    @State private var editValue: String = ""
    @State private var editComparison: Comparison = .equal
    
    var body: some View {
        NavigationStack {
            Form {
                // Get configuration for this filter key
                if let config = configurationForKey(filter.key) {
                    // Comparison picker
                    ComparisonInputView(
                        title: "Comparison",
                        comparison: $editComparison
                    )
                    
                    // Value input based on field type
                    switch config.fieldType {
                    case .text(let placeholder):
                        TextInputView(
                            title: config.displayName,
                            text: $editValue,
                            placeholder: placeholder
                        )
                        
                    case .numeric(let placeholder, let range, let step):
                        NumericTextInputView(
                            title: config.displayName,
                            text: $editValue,
                            placeholder: placeholder,
                            range: range,
                            step: step
                        )
                        
                    case .enumeration(let options):
                        EnumerationInputView(
                            title: config.displayName,
                            selection: $editValue,
                            options: options
                        )
                    }
                } else {
                    // Fallback for unknown filter keys
                    ComparisonInputView(
                        title: "Comparison",
                        comparison: $editComparison
                    )
                    
                    TextInputView(
                        title: filter.key.capitalized,
                        text: $editValue,
                        placeholder: "Enter value"
                    )
                }
            }
            .navigationTitle("Edit Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Update") {
                        updateAndDismiss()
                    }
                }
                
                ToolbarItem(placement: .bottomBar) {
                    Button("Delete", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear {
            loadFilterValues()
        }
    }
    
    private func loadFilterValues() {
        editValue = filter.value
        editComparison = filter.comparison
    }
    
    private func updateAndDismiss() {
        let trimmed = editValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        let updatedFilter = SearchFilter(filter.key, editComparison, trimmed)
        onUpdate(updatedFilter)
        dismiss()
    }
}
