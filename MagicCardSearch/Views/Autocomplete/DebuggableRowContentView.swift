import SwiftUI

#if DEBUG
struct DebuggableRowContentView<Content: View>: View {
    let suggestion: AutocompleteSuggestion
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading) {
            content()
            Text("score: \(suggestion.biasedScore, specifier: "%.4f") (raw: \(suggestion.score, specifier: "%.4f"))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
#else
// swiftlint:disable:next identifier_name
func DebuggableRowContentView<Content: View>(suggestion: Suggestion, @ViewBuilder content: () -> Content) -> Content {
    content()
}
#endif
