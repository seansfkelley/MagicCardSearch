import SwiftUI
import ScryfallKit

struct CardPricesSection: View {
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

    var body: some View {
        ZStack {
            HStack {
                Label("Buy It", systemImage: "dollarsign")
                    .labelReservedIconWidth(iconWidth)
                    .font(.headline)
                    .padding(.trailing, 8)
                    .opacity(textOpacity)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Label("Buy It", systemImage: "dollarsign")
                        .labelReservedIconWidth(iconWidth)
                        .font(.headline)
                        .padding(.trailing, 8)
                        .hidden()
                    
                    if let purchaseUris {
                        ForEach(Vendor.allCases, id: \.rawValue) { vendor in
                            if let url = purchaseUris[vendor.rawValue] {
                                VendorButton(vendor: vendor, prices: prices, url: url)
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

    private enum PriceType {
        case regular, foil, etched

        var icon: String? {
            switch self {
            case .regular: nil
            case .foil: "sparkles.2"
            case .etched: "sparkles.2"
            }
        }
    }

    private enum Vendor: String, CaseIterable {
        case tcgplayer, cardmarket, cardhoarder
        
        var displayName: String {
            switch self {
            case .tcgplayer: "TCGplayer"
            case .cardmarket: "Cardmarket"
            case .cardhoarder: "Cardhoarder"
            }
        }

        var symbol: String {
            switch self {
            case .tcgplayer: "$"
            case .cardmarket: "€"
            case .cardhoarder: "TIX " // Note the space.
            }
        }

        func price(from prices: Card.Prices, for type: PriceType) -> String? {
            switch self {
            case .tcgplayer:
                switch type {
                case .regular: prices.usd
                case .foil: prices.usdFoil
                case .etched: prices.usdEtched
                }
            case .cardmarket:
                switch type {
                case .regular: prices.eur
                case .foil: prices.eurFoil
                case .etched: prices.eurEtched
                }
            case .cardhoarder:
                switch type {
                case .regular: prices.tix
                case .foil: nil
                case .etched: nil
                }
            }
        }
    }

    private struct VendorButton: View {
        let vendor: Vendor
        let prices: Card.Prices
        let url: String

        var body: some View {
            Link(destination: URL(string: url)!) {
                HStack {
                    Image(vendor.rawValue)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    
                    Text(vendor.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                    
                    let priceEntries = [PriceType.regular, .foil, .etched].compactMap { type in
                        vendor.price(from: prices, for: type).map { (type, $0) }
                    }
                    if !priceEntries.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(priceEntries, id: \.0) { entry in
                                let (type, price) = entry
                                HStack(spacing: 2) {
                                    if let icon = type.icon {
                                        Image(systemName: icon)
                                            .font(.caption)
                                    }
                                    Text(vendor.symbol + price)
                                        .font(.subheadline)
                                }
                                .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                .fixedSize()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
            }
        }
    }
}
