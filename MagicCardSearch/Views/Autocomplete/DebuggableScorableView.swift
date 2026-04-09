import SwiftUI

protocol DebuggableScorable {
    var rawScore: Double { get }
    var biasedScore: Double { get }
}

extension Double: DebuggableScorable {
    var rawScore: Double { self }
    var biasedScore: Double { self }
}

extension AutocompleteSuggestion: DebuggableScorable {}

#if DEBUG
struct DebuggableScorableView<Content: View>: View {
    let scorable: DebuggableScorable
    @ViewBuilder let content: () -> Content
    @AppStorage("debugShowScores") private var showScores = true

    var body: some View {
        if showScores {
            VStack(alignment: .leading) {
                content()
                Text("score: \(scorable.biasedScore, specifier: "%.4f") (raw: \(scorable.rawScore, specifier: "%.4f"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            content()
        }
    }
}
#else
// swiftlint:disable:next identifier_name
func DebuggableScorableView<Content: View>(scorable: DebuggableScorable, @ViewBuilder content: () -> Content) -> Content {
    content()
}
#endif
