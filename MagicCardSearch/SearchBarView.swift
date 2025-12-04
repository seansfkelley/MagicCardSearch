////
////  SearchBarView.swift
////  MagicCardSearch
////
////  Created by Sean Kelley on 2025-12-03.
////
//
//import SwiftUI
//import WrappingHStack
//
//struct SearchBarView: View {
//    @Binding var unparsedInputText: String
//    @FocusState private var isFocused: Bool
//    @State private var editingIndex: Int?
//    @State private var isEditing: Bool = false
//    @State var parsedTerms: [ScryfallFilter] = []
//    
//    private let keyValueUnquotedPattern = #/^[a-zA-Z]+:[^ "]+$/#
//    private let keyValueQuotedPattern = #/^[a-zA-Z]+:"[^"]+"$/#
//    private let quotedPattern = #/^"[^"]+"$/#
//    private let freeTextPattern = #/^[^:"]+$/#
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            if !searchTerms.isEmpty {
//                WrappingHStack(alignment: .leading, spacing: .constant(8), lineSpacing: 8) {
//                    ForEach(Array(parsedTerms.enumerated()), id: \.element.id) { index, term in
//                        SearchPillView(
//                            term: term,
//                            onTap: {
//                                editingIndex = index
//                                isEditing = true
//                            },
//                            onDelete: {
//                                parsedTerms.remove(at: index)
//                            }
//                        )
//                    }
//                }
//            }
//            
//            HStack(spacing: 12) {
//                Image(systemName: "magnifyingglass")
//                    .foregroundStyle(.secondary)
//                
//                TextField("Search for cards...", text: $searchText)
//                    .textFieldStyle(.plain)
//                    .focused($isFocused)
//                    .textInputAutocapitalization(.never)
//                    .autocorrectionDisabled(true)
//                    .textContentType(.none)
//                    .onSubmit {
//                        addTermsFromText(isEnterPressed: true)
//                    }
//            }
//        }
//        .padding(.horizontal, 16)
//        .padding(.vertical, 12)
//        .background(.ultraThinMaterial)
//        .onChange(of: unparsedInputText) { oldValue, newValue in
//            // Only check for space when text is growing
//            if newValue.count > oldValue.count && newValue.hasSuffix(" ") {
//                checkAndCreatePillOnSpace()
//            }
//        }
//        .sheet(isPresented: $isEditing) {
//            if let index = editingIndex, index < searchTerms.count {
//                EditPillSheet(
//                    term: searchTerms[index],
//                    editText: $editAlertText,
//                    editNumber: $editNumber,
//                    editColor: $editColor,
//                    onUpdate: { newValue in
//                        searchTerms[index].value = newValue
//                        showingEditSheet = false
//                    },
//                    onDelete: {
//                        searchTerms.remove(at: index)
//                        showingEditSheet = false
//                    }
//                )
//            }
//        }
//    }
//    
//    private func checkAndCreatePillOnSpace() {
//        let trimmed = String(unparsedInputText.trimmingCharacters(in: .whitespaces))
//        
//        if textWithoutSpace.wholeMatch(of: keyValueUnquotedPattern) != nil ||
//           textWithoutSpace.wholeMatch(of: keyValueQuotedPattern) != nil ||
//           textWithoutSpace.wholeMatch(of: quotedPattern) != nil {
//            print("DEBUG: Creating pill with text: '\(text)'")
//            // For now, all pills are free text type
//            // You can enhance this later to determine type based on the pattern matched
//            let newTerm = SearchTerm(type: .freeText, value: .text(text))
//            searchTerms.append(newTerm)
//            searchText = ""
//            print("DEBUG: Pill created. Total pills: \(searchTerms.count)")
//        }
//    }
//    
//    private func addTermsFromText(isEnterPressed: Bool) {
//        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
//        guard !trimmed.isEmpty else { return }
//        
//        print("DEBUG: addTermsFromText called with: '\(trimmed)', isEnterPressed: \(isEnterPressed)")
//        
//        // On enter, check all patterns including free text
//        let matchesKeyValueUnquoted = trimmed.wholeMatch(of: keyValueUnquotedPattern) != nil
//        let matchesKeyValueQuoted = trimmed.wholeMatch(of: keyValueQuotedPattern) != nil
//        let matchesQuoted = trimmed.wholeMatch(of: quotedPattern) != nil
//        let matchesFreeText = trimmed.wholeMatch(of: freeTextPattern) != nil
//        
//        print("DEBUG: keyValueUnquoted: \(matchesKeyValueUnquoted), keyValueQuoted: \(matchesKeyValueQuoted), quoted: \(matchesQuoted), freeText: \(matchesFreeText)")
//        
//        if matchesKeyValueUnquoted || matchesKeyValueQuoted || matchesQuoted ||
//           (isEnterPressed && matchesFreeText) {
//            createPill(from: trimmed)
//        } else {
//            print("DEBUG: No pattern matched!")
//        }
//    }
//}
//
//// MARK: - Search Term Model
//
//enum ScryfallFilter {
//    case set(FilterType.freeText)
//    case color(FilterType.freeText)
//    case manaValue(FilterType.numerical)
//    case power(FilterType.numerical)
//    case toughness(FilterType.numerical)
//    case type(FilterType.freeText)
//}
//
//enum FilterType {
//    case freeText
//    case numerical(Range<Int>)
//    case enumeration(Array<String>)
//}
//
//// MARK: - Edit Pill Sheet
//
//struct EditPillSheet: View {
//    let term: SearchTerm
//    @Binding var editText: String
//    @Binding var editNumber: Int
//    @Binding var editColor: CardColor
//    let onUpdate: (SearchTermValue) -> Void
//    let onDelete: () -> Void
//    
//    @Environment(\.dismiss) private var dismiss
//    
//    var body: some View {
//        NavigationStack {
//            VStack(spacing: 20) {
//                switch term.type {
//                case .freeText:
//                    TextField("Search term", text: $editText)
//                        .textFieldStyle(.roundedBorder)
//                        .textInputAutocapitalization(.never)
//                        .autocorrectionDisabled(true)
//                
//                case .numerical:
//                    HStack {
//                        TextField("Number", value: $editNumber, format: .number)
//                            .textFieldStyle(.roundedBorder)
//                            .keyboardType(.numberPad)
//                        
//                        VStack(spacing: 4) {
//                            Button(action: { editNumber += 1 }) {
//                                Image(systemName: "plus.circle.fill")
//                                    .font(.title2)
//                                    .foregroundStyle(.blue)
//                            }
//                            
//                            Button(action: { editNumber = max(0, editNumber - 1) }) {
//                                Image(systemName: "minus.circle.fill")
//                                    .font(.title2)
//                                    .foregroundStyle(.blue)
//                            }
//                        }
//                    }
//                
//                case .enumeration:
//                    Picker("Color", selection: $editColor) {
//                        ForEach(CardColor.allCases, id: \.self) { color in
//                            Text(color.rawValue).tag(color)
//                        }
//                    }
//                    .pickerStyle(.menu)
//                    .labelsHidden()
//                }
//            }
//            .padding()
//            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Delete", role: .destructive) {
//                        onDelete()
//                    }
//                }
//                
//                ToolbarItem(placement: .confirmationAction) {
//                    Button("Update") {
//                        updateAndDismiss()
//                    }
//                }
//            }
//        }
//        .presentationDetents([.height(200)])
//    }
//    
//    private func updateAndDismiss() {
//        let newValue: SearchTermValue
//        
//        switch term.type {
//        case .freeText:
//            let trimmed = editText.trimmingCharacters(in: .whitespaces)
//            guard !trimmed.isEmpty else { return }
//            newValue = .text(trimmed)
//            
//        case .numerical:
//            newValue = .number(editNumber)
//            
//        case .enumeration:
//            newValue = .color(editColor)
//        }
//        
//        onUpdate(newValue)
//    }
//}
//
//// MARK: - Search Pill View
//
//struct SearchPillView: View {
//    let filter: ScryfallFilter
//    let onTap: () -> Void
//    let onDelete: () -> Void
//    
//    @State private var isPressing = false
//    @State private var isPressingDelete = false
//    
//    var body: some View {
//        HStack(spacing: 0) {
//            // Main pill body
//            Text(term.displayText)
//                .font(.body)
//                .foregroundStyle(.primary)
//                .padding(.leading, 16)
//                .padding(.trailing, 12)
//                .padding(.vertical, 10)
//                .background(isPressing ? Color.gray.opacity(0.3) : Color.clear)
//                .contentShape(Rectangle())
//                .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity) {
//                    // Never completes
//                } onPressingChanged: { pressing in
//                    isPressing = pressing
//                    if !pressing {
//                        onTap()
//                    }
//                }
//            
//            // Divider
//            Rectangle()
//                .fill(Color.gray.opacity(0.3))
//                .frame(width: 1)
//                .padding(.vertical, 6)
//            
//            // Delete button (right side with semicircle)
//            Image(systemName: "xmark")
//                .font(.body)
//                .foregroundStyle(.secondary)
//                .frame(width: 36)
//                .frame(maxHeight: .infinity)
//                .background(isPressingDelete ? Color.gray.opacity(0.3) : Color.clear)
//                .contentShape(Rectangle())
//                .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity) {
//                    // Never completes
//                } onPressingChanged: { pressing in
//                    isPressingDelete = pressing
//                    if !pressing {
//                        onDelete()
//                    }
//                }
//        }
//        .fixedSize(horizontal: true, vertical: false)
//        .frame(height: 40)
//        .background(pillColor)
//        .clipShape(Capsule())
//        .overlay(
//            Capsule()
//                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
//        )
//    }
//    
//    private var pillColor: Color {
//        return Color.gray.opacity(0.2)
//    }
//}
//
//// MARK: - Preview
//
//#Preview {
//    VStack {
//        Spacer()
//        SearchBarView(searchText: .constant(""))
//    }
//}
//
//#Preview("With Sample Terms") {
//    VStack {
//        Spacer()
//        SearchBarView(
//            searchText: .constant(""),
//            searchTerms: [
//                SearchTerm(type: .freeText, value: .text("lightning")),
//                SearchTerm(type: .numerical, value: .number(3)),
//                SearchTerm(type: .enumeration, value: .color(.red)),
//                SearchTerm(type: .freeText, value: .text("color:blue")),
//                SearchTerm(type: .freeText, value: .text("\"exact match\""))
//            ]
//        )
//    }
//}
