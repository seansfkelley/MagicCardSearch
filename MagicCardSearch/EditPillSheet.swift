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

    @State private var editValue: String = ""
    @State private var editComparison: Comparison = .equal

    var body: some View {
        NavigationStack {
            Form {
                if let config = configurationForKey(filter.key) {
                    switch config.fieldType {
                    case .text(let placeholder):
                        ComparisonInputView($editComparison, mode: .equalityOnly)
                        TextInputView(
                            text: $editValue,
                            placeholder: placeholder
                        )
                        .onSubmit {
                            updateAndDismiss()
                        }

                    case .numeric(let placeholder, let range, let step):
                        ComparisonInputView($editComparison)
                        NumericTextInputView(
                            text: $editValue,
                            placeholder: placeholder,
                            range: range,
                            step: step
                        )
                        .onSubmit {
                            updateAndDismiss()
                        }

                    case .enumeration(let options):
                        ComparisonInputView($editComparison, mode: .equalityOnly)
                        EnumerationInputView(
                            selection: $editValue,
                            options: options
                        )
                    }
                } else {
                    ComparisonInputView($editComparison, mode: .equalityOnly)
                    TextInputView(
                        text: $editValue,
                        placeholder: "Enter value"
                    )
                    .onSubmit {
                        updateAndDismiss()
                    }
                }
                
                Section {
                    Button(action: updateAndDismiss) {
                        HStack {
                            Spacer()
                            Text("Update")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Delete", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                    .foregroundStyle(.red)
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

#Preview("Text Field - Oracle Text") {
    EditPillSheet(
        filter: SearchFilter("oracle", .equal, "when ~ enters"),
        onUpdate: { updatedFilter in
            print("Updated filter: \(updatedFilter)")
        },
        onDelete: {
            print("Deleted filter")
        }
    )
}

#Preview("Numeric Field - Mana Value") {
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

#Preview("Enumeration Field - Format") {
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
