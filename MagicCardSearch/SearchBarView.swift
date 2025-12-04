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
    @State private var editingIndex: Int?
    @State private var isEditing: Bool = false
    @State var parsedFilters: [SearchFilter] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !searchTerms.isEmpty {
                WrappingHStack(alignment: .leading, spacing: .constant(8), lineSpacing: 8) {
                    ForEach(Array(parsedFilters.enumerated()), id: \.element.id) { index, term in
                        SearchPillView(
                            term: term,
                            onTap: {
                                editingIndex = index
                                isEditing = true
                            },
                            onDelete: {
                                parsedTerms.remove(at: index)
                            }
                        )
                    }
                }
            }
            
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search for cards...", text: $searchText)
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
            if let index = editingIndex, index < searchTerms.count {
                EditPillSheet(
                    term: searchTerms[index],
                    editText: $editAlertText,
                    editNumber: $editNumber,
                    editColor: $editColor,
                    onUpdate: { newValue in
                        searchTerms[index].value = newValue
                        showingEditSheet = false
                    },
                    onDelete: {
                        searchTerms.remove(at: index)
                        showingEditSheet = false
                    }
                )
            }
        }
    }
    
    private func tryCreateNewFilterFromSearch() {
        let trimmed = String(unparsedInputText.trimmingCharacters(in: .whitespaces))
        if Some(parsed) = SearchFilter.from(trimmed) {
            parsedFilters.append(parsed)
        }
    }
}

// MARK: - Edit Pill Sheet

struct EditPillSheet: View {
    let filter: SearchFilter
    @Binding var editText: String
    @Binding var editNumber: Int
    let onUpdate: (SearchTermValue) -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                switch term.type {
                case .freeText:
                    TextField("Search term", text: $editText)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                
                case .numerical:
                    HStack {
                        TextField("Number", value: $editNumber, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                        
                        VStack(spacing: 4) {
                            Button(action: { editNumber += 1 }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                            }
                            
                            Button(action: { editNumber = max(0, editNumber - 1) }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                
                case .enumeration:
                    Picker("Color", selection: $editColor) {
                        ForEach(CardColor.allCases, id: \.self) { color in
                            Text(color.rawValue).tag(color)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Delete", role: .destructive) {
                        onDelete()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Update") {
                        updateAndDismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(200)])
    }
    
    private func updateAndDismiss() {
        let newValue: SearchTermValue
        
        switch term.type {
        case .freeText:
            let trimmed = editText.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            newValue = .text(trimmed)
            
        case .numerical:
            newValue = .number(editNumber)
            
        case .enumeration:
            newValue = .color(editColor)
        }
        
        onUpdate(newValue)
    }
}

// MARK: - Search Pill View

struct SearchPillView: View {
    let filter: ScryfallFilter
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressing = false
    @State private var isPressingDelete = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Main pill body
            Text(term.displayText)
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.leading, 16)
                .padding(.trailing, 12)
                .padding(.vertical, 10)
                .background(isPressing ? Color.gray.opacity(0.3) : Color.clear)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity) {
                    // Never completes
                } onPressingChanged: { pressing in
                    isPressing = pressing
                    if !pressing {
                        onTap()
                    }
                }
            
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)
                .padding(.vertical, 6)
            
            // Delete button (right side with semicircle)
            Image(systemName: "xmark")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 36)
                .frame(maxHeight: .infinity)
                .background(isPressingDelete ? Color.gray.opacity(0.3) : Color.clear)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity) {
                    // Never completes
                } onPressingChanged: { pressing in
                    isPressingDelete = pressing
                    if !pressing {
                        onDelete()
                    }
                }
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: 40)
        .background(pillColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var pillColor: Color {
        return Color.gray.opacity(0.2)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        SearchBarView(
            searchText: .constant(""),
            parsedSearchTerms: [
                SearchFilter(.set, .equal, "7ED"),
                SearchFilter(.manaValue, .greaterThanOrEqual, "4")
            ]
        )
    }
}
