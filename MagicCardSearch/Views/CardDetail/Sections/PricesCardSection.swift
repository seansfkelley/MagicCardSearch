import SwiftUI
import ScryfallKit

struct PricesCardSection: View {
    @ScaledMetric private var iconWidth = CardDetailConstants.defaultSectionIconWidth

    let prices: Card.Prices
    let purchaseUris: [String: String]?
    
    private let textFadeExtent: CGFloat = 30
    @State var textOpacity: CGFloat = 1
    
    static func hasPrices(card: Card) -> Bool {
        let usdAvailable = card.prices.usd != nil && !card.prices.usd!.isEmpty
        let eurAvailable = card.prices.eur != nil && !card.prices.eur!.isEmpty
        let tixAvailable = card.prices.tix != nil && !card.prices.tix!.isEmpty
        
        return usdAvailable || eurAvailable || tixAvailable
    }

    @ViewBuilder
    private var label: some View {
        Label("Buy It", systemImage: "dollarsign")
            .labelReservedIconWidth(iconWidth)
            .font(.headline)
            .padding(.trailing, 8)
    }

    var body: some View {
        ZStack {
            HStack {
                label.opacity(textOpacity)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    label.hidden()

                    if let purchaseUris {
                        ForEach(Vendor.allCases, id: \.rawValue) { vendor in
                            if let url = purchaseUris[vendor.rawValue] {
                                VendorButtonView(vendor: vendor, prices: prices, url: url)
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
            .onScrollGeometryChange(
                for: CGFloat.self,
                of: { geometry in
                    let x = geometry.contentOffset.x
                    return x > textFadeExtent ? textFadeExtent : x < 0 ? 0 : x
                },
                action: { _, currentValue in
                    textOpacity = (textFadeExtent - currentValue) / textFadeExtent
                })
            .mask {
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [.clear, .black],
                        startPoint: .leading,
                        endPoint: .trailing,
                    )
                    .frame(width: 20)
                    Rectangle()
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .leading,
                        endPoint: .trailing,
                    )
                    .frame(width: 20)
                }
            }
        }
        .padding()
    }
}
