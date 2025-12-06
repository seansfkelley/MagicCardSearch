//
//  SettingsSheetView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import SwiftUI

struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var enableGlobalFilters = true
    @State private var globalFilterText = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Global Filters") {
                    Toggle(isOn: $enableGlobalFilters) {
                        Text("Enable")
                    }
                    Text("Global filters, when enabled, are always applied to all searches implicitly. Use these if you only play paper or online, or if you only ever play one format, and don't want to have to always include those filters.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                
                    if enableGlobalFilters {
                        TextField("Filters...", text: $globalFilterText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
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
