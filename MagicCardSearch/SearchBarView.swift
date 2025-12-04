//
//  SearchBarView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI
import WrappingHStack

struct SearchBarView: View {
    @Binding var searchText: String
    @FocusState private var isFocused: Bool
    @State private var editingTermId: UUID?
    @State private var showingEditAlert = false
    @State private var editAlertText = ""
    @State var searchTerms: [SearchTerm] = []
    
    // Regex patterns for pill matching
    // These patterns check that the entire string matches completely
    private let keyValueUnquotedPattern = #/^[a-zA-Z]+:[^ "]+$/#
    private let keyValueQuotedPattern = #/^[a-zA-Z]+:"[^"]+"$/#
    private let quotedPattern = #/^"[^"]+"$/#
    private let freeTextPattern = #/^[^:"]+$/#
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                // Pills display
                if !searchTerms.isEmpty {
                    WrappingHStack(alignment: .leading, spacing: .constant(8), lineSpacing: 8) {
                        ForEach(searchTerms) { term in
                            SearchPillView(
                                term: term,
                                onTap: {
                                    editingTermId = term.id
                                    editAlertText = term.displayText
                                    showingEditAlert = true
                                },
                                onDelete: {
                                    deleteTerm(term)
                                }
                            )
                        }
                    }
                }
                
                // Input field
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
                            addTermsFromText(isEnterPressed: true)
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .onChange(of: searchText) { oldValue, newValue in
            // Only check for space when text is growing
            if newValue.count > oldValue.count && newValue.hasSuffix(" ") {
                checkAndCreatePillOnSpace()
            }
        }
        .alert("", isPresented: $showingEditAlert, presenting: editingTermId) { termId in
            TextField("", text: $editAlertText, prompt: Text("Search term"))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            
            Button("Delete", role: .destructive) {
                guard let term = searchTerms.first(where: { $0.id == termId }) else { return }
                deleteTerm(term)
            }
            
            Button("Update") {
                updateTerm(termId, with: .text(editAlertText))
            }
        }
    }
    
    private func checkAndCreatePillOnSpace() {
        // Get text without the trailing space
        let textWithoutSpace = String(searchText.dropLast())
        
        // Check if it matches one of the first three patterns (space-triggerable)
        // These patterns must match the ENTIRE string (not just contain the pattern)
        if textWithoutSpace.wholeMatch(of: keyValueUnquotedPattern) != nil ||
           textWithoutSpace.wholeMatch(of: keyValueQuotedPattern) != nil ||
           textWithoutSpace.wholeMatch(of: quotedPattern) != nil {
            // Create pill from this text
            createPill(from: textWithoutSpace)
        }
    }
    
    private func addTermsFromText(isEnterPressed: Bool) {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        print("DEBUG: addTermsFromText called with: '\(trimmed)', isEnterPressed: \(isEnterPressed)")
        
        // On enter, check all patterns including free text
        let matchesKeyValueUnquoted = trimmed.wholeMatch(of: keyValueUnquotedPattern) != nil
        let matchesKeyValueQuoted = trimmed.wholeMatch(of: keyValueQuotedPattern) != nil
        let matchesQuoted = trimmed.wholeMatch(of: quotedPattern) != nil
        let matchesFreeText = trimmed.wholeMatch(of: freeTextPattern) != nil
        
        print("DEBUG: keyValueUnquoted: \(matchesKeyValueUnquoted), keyValueQuoted: \(matchesKeyValueQuoted), quoted: \(matchesQuoted), freeText: \(matchesFreeText)")
        
        if matchesKeyValueUnquoted || matchesKeyValueQuoted || matchesQuoted ||
           (isEnterPressed && matchesFreeText) {
            createPill(from: trimmed)
        } else {
            print("DEBUG: No pattern matched!")
        }
    }
    
    private func createPill(from text: String) {
        print("DEBUG: Creating pill with text: '\(text)'")
        // For now, all pills are free text type
        // You can enhance this later to determine type based on the pattern matched
        let newTerm = SearchTerm(type: .freeText, value: .text(text))
        searchTerms.append(newTerm)
        searchText = ""
        print("DEBUG: Pill created. Total pills: \(searchTerms.count)")
    }
    
    private func updateTerm(_ termId: UUID, with newValue: SearchTermValue) {
        guard let index = searchTerms.firstIndex(where: { $0.id == termId }) else { return }
        searchTerms[index].value = newValue
    }
    
    private func deleteTerm(_ term: SearchTerm) {
        searchTerms.removeAll { $0.id == term.id }
    }
}

// MARK: - Search Term Model

enum SearchTermType {
    case freeText
    case numerical
    case enumeration
}

enum CardColor: String, CaseIterable {
    case white = "White"
    case blue = "Blue"
    case black = "Black"
    case red = "Red"
    case green = "Green"
    case colorless = "Colorless"
}

enum SearchTermValue {
    case text(String)
    case number(Int)
    case color(CardColor)
    
    var displayText: String {
        switch self {
        case .text(let string):
            return string
        case .number(let int):
            return "\(int)"
        case .color(let color):
            return color.rawValue
        }
    }
}

struct SearchTerm: Identifiable {
    let id = UUID()
    let type: SearchTermType
    var value: SearchTermValue
    
    var displayText: String {
        value.displayText
    }
}

// MARK: - Search Pill View

struct SearchPillView: View {
    let term: SearchTerm
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
        SearchBarView(searchText: .constant(""))
    }
}

#Preview("With Sample Terms") {
    VStack {
        Spacer()
        SearchBarView(
            searchText: .constant(""),
            searchTerms: [
                SearchTerm(type: .freeText, value: .text("lightning")),
                SearchTerm(type: .numerical, value: .number(3)),
                SearchTerm(type: .enumeration, value: .color(.red)),
                SearchTerm(type: .freeText, value: .text("color:blue")),
                SearchTerm(type: .freeText, value: .text("\"exact match\""))
            ]
        )
    }
}
