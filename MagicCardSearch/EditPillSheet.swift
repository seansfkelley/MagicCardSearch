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
    
    // State for editing different filter types
    @State private var editName: String = ""
    @State private var editSet: String = ""
    @State private var editSetComparison: StringComparison = .equal
    @State private var editManaValue: String = ""
    @State private var editManaValueComparison: Comparison = .equal
    @State private var editColors: [String] = []
    @State private var editColorComparison: Comparison = .equal
    @State private var editFormat: String = ""
    @State private var editFormatComparison: StringComparison = .equal
    
    var body: some View {
        NavigationStack {
            Form {
                switch filter {
                case .name(let name):
                    TextInputView(
                        title: "Card Name",
                        text: $editName,
                        placeholder: "Enter card name"
                    )
                    
                case .set(let comparison, let setCode):
                    StringComparisonInputView(
                        title: "Comparison",
                        comparison: $editSetComparison
                    )
                    
                    TextInputView(
                        title: "Set Code",
                        text: $editSet,
                        placeholder: "e.g. 7ED, MH3"
                    )
                    
                case .manaValue(let comparison, let value):
                    ComparisonInputView(
                        title: "Comparison",
                        comparison: $editManaValueComparison
                    )
                    
                    NumericTextInputView(
                        title: "Mana Value",
                        text: $editManaValue,
                        placeholder: "Enter mana value",
                        range: 0...20
                    )
                    
                case .color(let comparison, let colors):
                    ComparisonInputView(
                        title: "Comparison",
                        comparison: $editColorComparison
                    )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Colors")
                            .font(.headline)
                        
                        // Color selection interface would go here
                        Text("Colors: \(colors.joined(separator: ", "))")
                            .foregroundStyle(.secondary)
                    }
                    
                case .format(let comparison, let formatName):
                    StringComparisonInputView(
                        title: "Comparison",
                        comparison: $editFormatComparison
                    )
                    
                    EnumerationInputView(
                        title: "Format",
                        selection: $editFormat,
                        options: ["standard", "modern", "legacy", "vintage", "commander", "pioneer", "pauper"]
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
        switch filter {
        case .name(let name):
            editName = name
            
        case .set(let comparison, let setCode):
            editSetComparison = comparison
            editSet = setCode
            
        case .manaValue(let comparison, let value):
            editManaValueComparison = comparison
            editManaValue = value
            
        case .color(let comparison, let colors):
            editColorComparison = comparison
            editColors = colors
            
        case .format(let comparison, let formatName):
            editFormatComparison = comparison
            editFormat = formatName
        }
    }
    
    private func updateAndDismiss() {
        let updatedFilter: SearchFilter
        
        switch filter {
        case .name:
            let trimmed = editName.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            updatedFilter = .name(trimmed)
            
        case .set:
            let trimmed = editSet.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            updatedFilter = .set(editSetComparison, trimmed)
            
        case .manaValue:
            let trimmed = editManaValue.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            updatedFilter = .manaValue(editManaValueComparison, trimmed)
            
        case .color:
            guard !editColors.isEmpty else { return }
            updatedFilter = .color(editColorComparison, editColors)
            
        case .format:
            let trimmed = editFormat.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            updatedFilter = .format(editFormatComparison, trimmed)
        }
        
        onUpdate(updatedFilter)
        dismiss()
    }
}
