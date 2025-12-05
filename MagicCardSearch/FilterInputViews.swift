//
//  FilterInputViews.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI

// MARK: - Text Input

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

// MARK: - Numeric Text Input (with inline +/- buttons)

struct NumericTextInputView: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let range: ClosedRange<Int>
    let step: Int
    
    init(title: String, text: Binding<String>, placeholder: String = "", range: ClosedRange<Int> = 0...99, step: Int = 1) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.range = range
        self.step = step
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            HStack(spacing: 8) {
                Button(action: {
                    if let current = Int(text) {
                        text = String(max(range.lowerBound, current - step))
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                
                TextField(placeholder.isEmpty ? title : placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    if let current = Int(text) {
                        text = String(min(range.upperBound, current + step))
                    } else {
                        text = String(range.lowerBound)
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Numerical Input

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

// MARK: - Enumeration Input

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
                    Text(option.capitalized).tag(option)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
        }
    }
}

// MARK: - Comparison Input

struct ComparisonInputView: View {
    enum Mode {
        case equalityOnly     
        case all
    }
    
    @Binding var comparison: Comparison
    let mode: Mode
    
    init(_ comparison: Binding<Comparison>, mode: Mode = .all) {
        self._comparison = comparison
        self.mode = mode
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Comparison", selection: $comparison) {
                switch mode {
                case .equalityOnly:
                    Text("=").tag(Comparison.equal)
                    Text("≠").tag(Comparison.notEqual)
                    
                case .all:
                    Text("=").tag(Comparison.equal)
                    Text("≠").tag(Comparison.notEqual)
                    Text("<").tag(Comparison.lessThan)
                    Text("≤").tag(Comparison.lessThanOrEqual)
                    Text(">").tag(Comparison.greaterThan)
                    Text("≥").tag(Comparison.greaterThanOrEqual)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}

// MARK: - Previews

#Preview {
    struct PreviewWrapper: View {
        @State var cardName = "Counterspell"
        @State var manaValue = "2"
        @State var power = 4
        @State var format = "modern"
        @State var comparisonAll = Comparison.greaterThanOrEqual
        @State var comparisonEquality = Comparison.equal
        
        var body: some View {
            NavigationStack {
                Form {
                    Section("Text") {
                        TextInputView(
                            title: "Card Name",
                            text: $cardName,
                            placeholder: "Enter card name"
                        )
                    }
                    
                    Section("Numeric") {
                        NumericTextInputView(
                            title: "Mana Value",
                            text: $manaValue,
                            placeholder: "Enter mana value",
                            range: 0...20,
                            step: 1
                        )
                        
                        NumericalInputView(
                            title: "Power",
                            value: $power,
                            range: 0...15,
                            step: 1
                        )
                    }
                    
                    Section("Enumeration") {
                        EnumerationInputView(
                            title: "Format",
                            selection: $format,
                            options: [
                                "standard", "modern", "legacy", "vintage",
                                "commander", "pioneer", "pauper", "historic"
                            ]
                        )
                    }
                    
                    Section("Comparison - All Options") {
                        ComparisonInputView($comparisonAll, mode: .all)
                    }
                    
                    Section("Comparison - Equality Only") {
                        ComparisonInputView($comparisonEquality, mode: .equalityOnly)
                    }
                }
            }
        }
    }
    
    return PreviewWrapper()
}
