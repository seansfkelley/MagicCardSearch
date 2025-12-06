//
//  FilterPillListView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import SwiftUI
import WrappingHStack

struct FilterPillListView: View {
    @Binding var filters: [SearchFilter]
    @FocusState var textFieldFocus: Bool
    @State private var unparsedInputText: String = ""
    @State private var editingState: EditableItem?
    
    let placeholder: String
    let showIcon: Bool
    
    init(
        filters: Binding<[SearchFilter]>,
        textFieldFocus: FocusState<Bool>,
        showIcon: Bool = true,
        placeholder: String = "Add filters..."
    ) {
        self._filters = filters
        self._textFieldFocus = textFieldFocus
        self.showIcon = showIcon
        self.placeholder = placeholder
    }
    
    struct EditableItem: Identifiable {
        var id: Int
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !filters.isEmpty {
                WrappingHStack(alignment: .leading, spacing: .constant(8), lineSpacing: 8) {
                    ForEach(Array(filters.enumerated()), id: \.offset) { index, filter in
                        SearchPillView(
                            filter: filter,
                            onTap: {
                                editingState = EditableItem(id: index)
                            },
                            onDelete: {
                                filters.remove(at: index)
                            }
                        )
                    }
                }
            }
            
            HStack(spacing: 12) {
                if (showIcon) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                }
                
                TextField(placeholder, text: $unparsedInputText)
                    .textFieldStyle(.plain)
                    .focused($textFieldFocus)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textContentType(.none)
                    .onSubmit {
                        createNewFilterFromSearch(fallbackToNameFilter: false)
                    }
                
                if !unparsedInputText.isEmpty {
                    Button(action: {
                        unparsedInputText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onChange(of: unparsedInputText) { (previous: String, current: String) in
            if previous.count < current.count && current.hasSuffix(" ") {
                createNewFilterFromSearch(fallbackToNameFilter: false)
            }
        }
        .sheet(item: $editingState) { state in
            EditPillSheet(
                filter: filters[state.id],
                onUpdate: { updatedFilter in
                    filters[state.id] = updatedFilter
                    editingState = nil
                },
                onDelete: {
                    filters.remove(at: state.id)
                    editingState = nil
                }
            )
            .presentationDetents([.medium])
        }
    }
    
    private func createNewFilterFromSearch(fallbackToNameFilter: Bool) {
        let trimmed = unparsedInputText.trimmingCharacters(in: .whitespaces)
        let unquoted = stripMatchingQuotes(from: trimmed)
        
        if let filter = SearchFilter.from(unquoted) {
            filters.append(filter)
            unparsedInputText = ""
        } else if fallbackToNameFilter && !unquoted.isEmpty {
            filters.append(SearchFilter("name", .equal, unquoted))
            unparsedInputText = ""
        }
    }
    
    private func stripMatchingQuotes(from string: String) -> String {
        if string.hasPrefix("\"") && string.hasSuffix("\"") && string.count >= 2 {
            return String(string.dropFirst().dropLast())
        } else if string.hasPrefix("'") && string.hasSuffix("'") && string.count >= 2 {
            return String(string.dropFirst().dropLast())
        } else {
            return string
        }
    }
}
