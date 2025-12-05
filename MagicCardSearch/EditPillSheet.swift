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
                    ComparisonInputView($editComparison)
                    
                    // Value input based on field type from configuration
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
                    ComparisonInputView($editComparison)
                    
                    TextInputView(
                        title: filter.key.capitalized,
                        text: $editValue,
                        placeholder: "Enter value"
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Update") {
                        updateAndDismiss()
                    }
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

#Preview("Free Text - Oracle") {
    EditPillSheet(
        filter: SearchFilter("oracle", .equal, "tap"),
        onUpdate: { updatedFilter in
            print("Updated filter: \(updatedFilter)")
        },
        onDelete: {
            print("Deleted filter")
        }
    )
}

#Preview("Enumeration - Format") {
    EditPillSheet(
        filter: SearchFilter("format", .equal, "commander"),
        onUpdate: { updatedFilter in
            print("Updated filter: \(updatedFilter)")
        },
        onDelete: {
            print("Deleted filter")
        }
    )
}

#Preview("Numeric - Mana Value") {
    EditPillSheet(
        filter: SearchFilter("manavalue", .greaterThanOrEqual, "4"),
        onUpdate: { updatedFilter in
            print("Updated filter: \(updatedFilter)")
        },
        onDelete: {
            print("Deleted filter")
        }
    )
}
