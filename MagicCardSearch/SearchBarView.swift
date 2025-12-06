//
//  SearchBarView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI
import WrappingHStack

struct SearchBarView: View {
    @Binding var filters: [SearchFilter]
    @FocusState private var isFocused: Bool
    @State private var unparsedInputText: String = ""
    @State private var editingState: EditableItem?
    
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
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField(filters.isEmpty ? "Search for cards..." : "Add filters...", text: $unparsedInputText)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textContentType(.none)
                    .keyboardType(.asciiCapable)
                    .onSubmit {
                        createNewFilterFromSearch(fallbackToNameFilter: true)
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .onChange(of: unparsedInputText) { (previous: String, current: String) in
            if previous.count < current.count && current.hasSuffix(" ") {
                createNewFilterFromSearch()
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
    
    private func createNewFilterFromSearch(fallbackToNameFilter: Bool = false) {
        let trimmed = unparsedInputText.trimmingCharacters(in: .whitespaces)
        
        if let filter = SearchFilter.from(trimmed) {
            filters.append(filter)
            unparsedInputText = ""
        } else if fallbackToNameFilter {
            let unquoted = stripMatchingQuotes(from: trimmed)
            if !unquoted.isEmpty {
                filters.append(SearchFilter("name", .equal, unquoted))
                unparsedInputText = ""
            }
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

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var filters: [SearchFilter] = [
            SearchFilter("set", .equal, "7ED"),
            SearchFilter("manavalue", .greaterThanOrEqual, "4"),
            SearchFilter("power", .greaterThan, "3"),
        ]
        
        var body: some View {
            VStack {
                Spacer()
                SearchBarView(filters: $filters)
            }
        }
    }
    
    return PreviewWrapper()
}

