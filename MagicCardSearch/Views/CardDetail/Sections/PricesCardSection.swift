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

    private var hasPrices: Bool {
        let usdAvailable = prices.usd != nil && !prices.usd!.isEmpty
        let eurAvailable = prices.eur != nil && !prices.eur!.isEmpty
        let tixAvailable = prices.tix != nil && !prices.tix!.isEmpty
        
        return usdAvailable || eurAvailable || tixAvailable
    }

    var body: some View {
        if hasPrices {
            divider()
            HStack {
                Label("Buy It", systemImage: "dollarsign")
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
