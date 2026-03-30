import SwiftUI

struct SearchSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let editingState: SearchEditingState
    let warnings: [String]
    let onSearch: () -> Void

    @State private var showSyntaxReference = false

    var body: some View {
        AutocompleteView(editingState: editingState, onSearch: onSearch)
            .safeAreaInset(edge: .bottom) {
                SearchBarAndPillsView(editingState: editingState, warnings: warnings, onSearch: onSearch)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSyntaxReference = true
                    } label: {
                        Image(systemName: "book")
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSyntaxReference) {
                NavigationStack {
                    SyntaxReferenceView()
                }
            }
    }
}
