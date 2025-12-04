//
//  SearchBarView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI
import WrappingHStack

struct SearchBarView: View {
    @Binding var unparsedInputText: String
    @FocusState private var isFocused: Bool
    @State private var editingFilter: SearchFilter?
    @State private var editingIndex: Int?
    @State private var isEditing: Bool = false
    @State var parsedFilters: [SearchFilter] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !parsedFilters.isEmpty {
                WrappingHStack(alignment: .leading, spacing: .constant(8), lineSpacing: 8) {
                    ForEach(Array(parsedFilters.enumerated()), id: \.offset) { index, filter in
                        SearchPillView(
                            filter: filter,
                            onTap: {
                                editingFilter = filter
                                editingIndex = index
                                isEditing = true
                            },
                            onDelete: {
                                parsedFilters.remove(at: index)
                            }
                        )
                    }
                }
            }
            
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search for cards...", text: $unparsedInputText)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textContentType(.none)
                    .onSubmit {
                        tryCreateNewFilterFromSearch()
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .onChange(of: unparsedInputText) { oldValue, newValue in
            // Only check for space when text is growing
            if newValue.count > oldValue.count && newValue.hasSuffix(" ") {
                tryCreateNewFilterFromSearch()
            }
        }
        .sheet(isPresented: $isEditing) {
            if let filter = editingFilter, let index = editingIndex {
                EditPillSheet(
                    filter: filter,
                    onUpdate: { updatedFilter in
                        parsedFilters[index] = updatedFilter
                        isEditing = false
                    },
                    onDelete: {
                        parsedFilters.remove(at: index)
                        isEditing = false
                    }
                )
                .presentationDetents([.fraction(0.5)])
            }
        }
    }
    
    private func tryCreateNewFilterFromSearch() {
        let trimmed = String(unparsedInputText.trimmingCharacters(in: .whitespaces))
         if let parsed = SearchFilter.from(trimmed) {
             parsedFilters.append(parsed)
         }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        SearchBarView(
            unparsedInputText: .constant(""),
            parsedFilters: [
                .set(.equal, "7ED"),
                .manaValue(.greaterThanOrEqual, "4"),
            ]
        )
    }
}

