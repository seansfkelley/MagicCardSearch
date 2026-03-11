import SwiftUI
import WebKit

struct SyntaxReferenceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchVisible = false
    @State private var page = WebPage()
    @State private var hasRunJavascript = false

    var body: some View {
        NavigationStack {
            WebView(page)
                .findNavigator(isPresented: $searchVisible)
                .navigationTitle("Syntax Reference")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            searchVisible.toggle()
                        } label: {
                            Label("Find in Page", systemImage: "magnifyingglass")
                        }
                    }
                }
                .onChange(of: page.isLoading) { _, isLoading in
                    if !isLoading && !hasRunJavascript {
                        hasRunJavascript = true
                        Task {
                            // Best-effort!
                            _ = try? await page.callJavaScript(
                                """
                                (function() {
                                    const header = document.getElementById('header');
                                    if (header != null) {
                                        header.remove();
                                    }
                                })();
                                """
                            )
                        }
                    }
                }
        }
        .onAppear {
            _ = page.load(URLRequest(url: URL(string: "https://scryfall.com/docs/syntax")!))
        }
    }
}

#Preview {
    SyntaxReferenceView()
}
