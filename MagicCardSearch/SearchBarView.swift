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
    var parsedFilters: [SearchFilter] = []
    
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
                                // Will need to be handled by parent
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
                        // Will need to be handled by parent
                        isEditing = false
                    },
                    onDelete: {
                        // Will need to be handled by parent
                        isEditing = false
                    }
                )
            }
        }
    }
    
    private func tryCreateNewFilterFromSearch() {
        let trimmed = String(unparsedInputText.trimmingCharacters(in: .whitespaces))
        // This needs proper parsing implementation
        // if let parsed = SearchFilter.from(trimmed) {
        //     parsedFilters.append(parsed)
        // }
    }
}

// MARK: - Generic Input Components

struct TextInputView: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let validation: ((String) -> Bool)?
    
    init(title: String, text: Binding<String>, placeholder: String = "", validation: ((String) -> Bool)? = nil) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.validation = validation
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            TextField(placeholder.isEmpty ? title : placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
        }
    }
}

struct NumericalInputView: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    
    init(title: String, value: Binding<Int>, range: ClosedRange<Int> = 0...99, step: Int = 1) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            HStack {
                TextField("Number", value: $value, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                
                VStack(spacing: 4) {
                    Button(action: {
                        value = min(range.upperBound, value + step)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        value = max(range.lowerBound, value - step)
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct EnumerationInputView: View {
    let title: String
    @Binding var selection: String
    let options: [String]
    
    init(title: String, selection: Binding<String>, options: [String]) {
        self.title = title
        self._selection = selection
        self.options = options
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }
}

struct ComparisonInputView: View {
    let title: String
    @Binding var comparison: Comparison
    
    init(title: String, comparison: Binding<Comparison>) {
        self.title = title
        self._comparison = comparison
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Picker(title, selection: $comparison) {
                Text("=").tag(Comparison.equal)
                Text("≠").tag(Comparison.notEqual)
                Text("<").tag(Comparison.lessThan)
                Text("≤").tag(Comparison.lessThanOrEqual)
                Text(">").tag(Comparison.greaterThan)
                Text("≥").tag(Comparison.greaterThanOrEqual)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

struct StringComparisonInputView: View {
    let title: String
    @Binding var comparison: StringComparison
    
    init(title: String, comparison: Binding<StringComparison>) {
        self.title = title
        self._comparison = comparison
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Picker(title, selection: $comparison) {
                Text("=").tag(StringComparison.equal)
                Text("≠").tag(StringComparison.notEqual)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

// MARK: - Edit Pill Sheet

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
                    
                    TextInputView(
                        title: "Mana Value",
                        text: $editManaValue,
                        placeholder: "Enter mana value"
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

// MARK: - Search Pill View

struct SearchPillView: View {
    let filter: SearchFilter
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressing = false
    @State private var isPressingDelete = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Main pill body
            Text(displayText)
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
    
    private var displayText: String {
        switch filter {
        case .name(let name):
            return name
            
        case .set(let comparison, let setCode):
            let op = comparison == .equal ? ":" : "!="
            return "set\(op)\(setCode)"
            
        case .manaValue(let comparison, let value):
            let op = comparisonSymbol(comparison)
            return "mv\(op)\(value)"
            
        case .color(let comparison, let colors):
            let op = comparisonSymbol(comparison)
            return "color\(op)\(colors.joined(separator: ","))"
            
        case .format(let comparison, let formatName):
            let op = comparison == .equal ? ":" : "!="
            return "format\(op)\(formatName)"
        }
    }
    
    private func comparisonSymbol(_ comparison: Comparison) -> String {
        switch comparison {
        case .equal: return ":"
        case .notEqual: return "!="
        case .lessThan: return "<"
        case .lessThanOrEqual: return "<="
        case .greaterThan: return ">"
        case .greaterThanOrEqual: return ">="
        }
    }
    
    private var pillColor: Color {
        switch filter {
        case .name:
            return Color.blue.opacity(0.2)
        case .set:
            return Color.purple.opacity(0.2)
        case .manaValue:
            return Color.orange.opacity(0.2)
        case .color:
            return Color.green.opacity(0.2)
        case .format:
            return Color.red.opacity(0.2)
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
