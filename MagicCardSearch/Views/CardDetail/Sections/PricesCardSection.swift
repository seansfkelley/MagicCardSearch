import SwiftUI
import ScryfallKit

struct PricesCardSection<DividerContent: View>: View {
    @ScaledMetric private var iconWidth = CardDetailConstants.defaultSectionIconWidth

    let prices: Card.Prices
    let purchaseUris: [String: String]?
    @ViewBuilder let divider: () -> DividerContent

    init(prices: Card.Prices, purchaseUris: [String: String]?, @ViewBuilder divider: @escaping () -> DividerContent = { EmptyView() }) {
        self.prices = prices
        self.purchaseUris = purchaseUris
        self.divider = divider
    }

    var body: some View {
        if !prices.isEmpty {
            divider()
            HStack {
                // Phrasing is important; this used to be "Buy It" but this didn't call attention to
                // the fact that you might have defaulted to a print of the card that was not
                // purchaseable, at least, not with your chosen currency.
                Label("Buy This Print", systemImage: "dollarsign")
                    .labelReservedIconWidth(iconWidth)
                    .font(.headline)
                    .padding(.trailing, 8)

                Spacer()

                VendorButtonView(prices: prices, purchaseUris: purchaseUris)
            }
            .padding()
        } else {
            EmptyView()
        }
    }
}
