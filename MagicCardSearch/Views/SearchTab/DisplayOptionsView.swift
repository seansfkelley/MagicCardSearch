import SwiftUI

struct DisplayOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var searchConfig: SearchConfiguration
    
    @State private var workingConfig = SearchConfiguration()
    
    init(searchConfig: Binding<SearchConfiguration>) {
        self._searchConfig = searchConfig
        self._workingConfig = State(wrappedValue: searchConfig.wrappedValue)
    }
    
    private var hasNonDefaultSettings: Bool {
        workingConfig != SearchConfiguration.defaultConfig
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Display Mode", selection: $workingConfig.uniqueMode) {
                        ForEach(SearchConfiguration.UniqueMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } footer: {
                    Text("Use the `unique:` filter to temporarily override this for one search.")
                }
                
                Section {
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
                } footer: {
                    Text("Use the `order:` and `dir:` filters to temporarily override these for one search.")
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
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        searchConfig = workingConfig
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }
}
