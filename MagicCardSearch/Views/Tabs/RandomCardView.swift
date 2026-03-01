import SwiftUI

struct RandomCardView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Coming Soon",
                systemImage: "shuffle",
                description: Text("Random card discovery will be available in a future update.")
            )
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
