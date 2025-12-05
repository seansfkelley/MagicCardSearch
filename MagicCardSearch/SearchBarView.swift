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
    @State private var editingFilter: SearchFilter?
    @State private var editingIndex: Int?
    @State private var isEditing: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !filters.isEmpty {
                WrappingHStack(alignment: .leading, spacing: .constant(8), lineSpacing: 8) {
                    ForEach(Array(filters.enumerated()), id: \.offset) { index, filter in
                        SearchPillView(
                            filter: filter,
                            onTap: {
                                editingFilter = filter
                                editingIndex = index
                                isEditing = true
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
                    .onSubmit {
                        createNewFilterFromSearch(fallbackToNameFilter: true)
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .onChange(of: unparsedInputText) { oldValue, newValue in
            if newValue.count > oldValue.count && newValue.hasSuffix(" ") {
                createNewFilterFromSearch()
            }
        }
        .sheet(isPresented: $isEditing) {
            if let filter = editingFilter, let index = editingIndex {
                EditPillSheet(
                    filter: filter,
                    onUpdate: { updatedFilter in
                        filters[index] = updatedFilter
                        isEditing = false
                    },
                    onDelete: {
                        filters.remove(at: index)
                        isEditing = false
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }
    
    private func createNewFilterFromSearch(fallbackToNameFilter: Bool = false) {
        let trimmed = unparsedInputText.trimmingCharacters(in: .whitespaces)
        if let filter = SearchFilter.from(trimmed) {
            filters.append(filter)
            unparsedInputText = ""
        } else if fallbackToNameFilter {
            filters.append(SearchFilter("name", .equal, trimmed))
            unparsedInputText = ""
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

