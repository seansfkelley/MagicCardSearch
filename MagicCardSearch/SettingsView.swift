//
//  SettingsSheetView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var globalFiltersSettings: GlobalFiltersSettings
    @FocusState private var isFilterFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Global Filters") {
                    Toggle(isOn: $globalFiltersSettings.isEnabled) {
                        Text("Enable")
                    }
                    .onChange(of: globalFiltersSettings.isEnabled) { _, _ in
                        globalFiltersSettings.save()
                    }
                    
                    Text("Global filters, when enabled, are always applied to all searches implicitly. Use these if you only play paper or online, or if you only ever play one format, and don't want to have to always include those filters.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                
                    if globalFiltersSettings.isEnabled {
                        FilterPillListView(
                            filters: $globalFiltersSettings.filters,
                            textFieldFocus: _isFilterFocused,
                            showIcon: false,
                            placeholder: "Add filter..."
                        )
                        .onChange(of: globalFiltersSettings.filters) { _, _ in
                            globalFiltersSettings.save()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
