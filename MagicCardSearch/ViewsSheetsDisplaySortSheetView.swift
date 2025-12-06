//
//  DisplaySortSheetView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import SwiftUI

struct DisplaySortSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var searchConfig: SearchConfiguration
    
    private var hasNonDefaultSettings: Bool {
        searchConfig != SearchConfiguration.defaultConfig
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Display") {
                    Picker("Display Mode", selection: $searchConfig.displayMode) {
                        ForEach(SearchConfiguration.DisplayMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                
                Section("Sort") {
                    Picker("Sort By", selection: $searchConfig.sortField) {
                        ForEach(SearchConfiguration.SortField.allCases, id: \.self) { field in
                            Text(field.rawValue).tag(field)
                        }
                    }
                    
                    Picker("Sort Order", selection: $searchConfig.sortOrder) {
                        ForEach(SearchConfiguration.SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                
                Section {
                    Button(action: {
                        searchConfig.resetToDefaults()
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
