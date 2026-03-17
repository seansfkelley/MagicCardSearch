import SwiftUI

struct AllPrintsCardSection: View {
    @ScaledMetric private var iconWidth = CardDetailConstants.defaultSectionIconWidth

    let oracleId: String
    let currentCardId: UUID

    @State private var showingPrintsSheet = false

    var body: some View {
        Button {
            showingPrintsSheet = true
        } label: {
            HStack {
                Label {
                    Text("All Prints")
                } icon: {
                    Image(systemName: "rectangle.stack")
                        .rotationEffect(.degrees(90))
                }
                .labelReservedIconWidth(iconWidth)
                .font(.headline)
                // pixel-push to make it line up with the adjacent DisclosureGroup
                .padding(.vertical, 3)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14)) // determinted empirically to match DisclosureGroup
                    .foregroundStyle(.primary)
                    .fontWeight(.semibold)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingPrintsSheet) {
            AllPrintsView(oracleId: oracleId, initialCardId: currentCardId)
        }
    }
}
