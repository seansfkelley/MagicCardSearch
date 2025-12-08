//
//  DisplaySortSheetView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import SwiftUI

struct DisplayOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var searchConfig: SearchConfiguration
    
    // Local state that will only be applied on confirmation
    @State private var workingConfig: SearchConfiguration = SearchConfiguration()
    
    init(searchConfig: Binding<SearchConfiguration>) {
        self._searchConfig = searchConfig
        // Use underscore to access the State wrapper directly and initialize it properly
        self._workingConfig = State(wrappedValue: searchConfig.wrappedValue)
    }
    
    private var hasNonDefaultSettings: Bool {
        workingConfig != SearchConfiguration.defaultConfig
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Display") {
                    Picker("Display Mode", selection: $workingConfig.uniqueMode) {
                        ForEach(SearchConfiguration.UniqueMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                
                Section("Sort") {
                    Picker("Sort by", selection: $workingConfig.sortField) {
                        ForEach(SearchConfiguration.SortField.allCases, id: \.self) { field in
                            Text(field.rawValue).tag(field)
                        }
                    }
                    
                    Picker("Sort order", selection: $workingConfig.sortOrder) {
                        ForEach(SearchConfiguration.SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                
                Section {
                    Button(action: {
                        workingConfig.resetToDefaults()
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Defaults")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(hasNonDefaultSettings ? .red : .gray)
                    }
                    .disabled(!hasNonDefaultSettings)
                }
            }
            .navigationTitle("Display & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        searchConfig = workingConfig
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                }
            }
        }
    }
}
