import SwiftUI

#if DEBUG
struct DebugTabView: View {
    var scryfallCatalogs: ScryfallCatalogs
    @AppStorage("debugShowScores") private var showScores = true
    @State private var scryfallCachesResult: Bool?
    @State private var catalogCachesResult: Bool?

    var body: some View {
        List {
            Section("Caches") {
                CacheDumpButton("Dump All Scryfall Caches", result: $scryfallCachesResult) {
                    CachingScryfallService.shared.dumpCaches()
                }
                CacheDumpButton("Dump Catalog Caches", result: $catalogCachesResult) {
                    scryfallCatalogs.dumpCaches()
                }
            }
            Section("Autocomplete") {
                Toggle("Show Autocomplete Scores", isOn: $showScores)
            }
        }
        .navigationTitle("Debug")
    }
}

private struct CacheDumpButton: View {
    let label: String
    @Binding var result: Bool?
    let action: () -> Bool

    init(_ label: String, result: Binding<Bool?>, action: @escaping () -> Bool) {
        self.label = label
        _result = result
        self.action = action
    }

    var body: some View {
        Button {
            result = action()
            Task {
                try? await Task.sleep(for: .seconds(2))
                result = nil
            }
        } label: {
            HStack {
                Text(label)
                Spacer()
                if let result {
                    Image(systemName: result ? "checkmark" : "xmark")
                        .foregroundStyle(result ? .green : .red)
                        .transition(.opacity)
                }
            }
        }
        .animation(.default, value: result)
    }
}
#endif
