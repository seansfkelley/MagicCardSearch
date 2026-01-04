import SwiftUI
import ScryfallKit

struct CardPricesSection: View {
    let prices: Card.Prices
    let purchaseUris: [String: String]?
    
    private let textFadeExtent: CGFloat = 36
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
                Text("Buy It")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.trailing, 8)
                    .opacity(textOpacity)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("Buy It")
                        .font(.headline)
                        .fontWeight(.semibold)
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
    
    private enum Vendor: String, CaseIterable {
        case tcgplayer, cardmarket, cardhoarder
        
        var displayName: String {
            switch self {
            case .tcgplayer: "TCGplayer"
            case .cardmarket: "Cardmarket"
            case .cardhoarder: "Cardhoarder"
            }
        }
        
        func price(from prices: Card.Prices) -> String? {
            switch self {
            case .tcgplayer: prices.usd.map { "$\($0)" }
            case .cardmarket: prices.eur.map { "€\($0)" }
            case .cardhoarder: prices.tix.map { "TIX \($0)" }
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
                        .lineLimit(1)
                    
                    if let price = vendor.price(from: prices) {
                        Text(price)
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
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
