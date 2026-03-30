import SwiftUI
import ScryfallKit
import OSLog
import SQLiteData

struct SearchSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var searchState: SearchState

    @State private var showSyntaxReference = false

    var body: some View {
        AutocompleteView(searchState: $searchState)
            .safeAreaInset(edge: .bottom) {
                SearchBarAndPillsView(searchState: $searchState)
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
