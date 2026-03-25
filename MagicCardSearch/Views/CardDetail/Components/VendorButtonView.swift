import SwiftUI
import ScryfallKit

enum Vendor: String, CaseIterable {
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

    // swiftlint:disable:next cyclomatic_complexity
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

enum PriceType {
    case regular, foil, etched

    var icon: String? {
        switch self {
        case .regular: nil
        case .foil: "sparkles.2"
        case .etched: "sparkles.2"
        }
    }
}

struct VendorButtonView: View {
    @AppStorage("preferredVendor") private var vendor: Vendor = .tcgplayer

    let prices: Card.Prices
    let purchaseUris: [String: String]?

    private var orderedPrices: [(PriceType, String)] {
        [PriceType.regular, .foil, .etched].compactMap { type in
            vendor.price(from: prices, for: type).map { (type, $0) }
        }
    }

    var body: some View {
        if let url = purchaseUris?[vendor.rawValue] {
            Link(destination: URL(string: url)!) {
                HStack {
                    Image(vendor.rawValue)
                        .resizable()
                        .aspectRatio(contentMode: .fit)

                    if orderedPrices.isEmpty {
                        Text(vendor.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    }

                    if !orderedPrices.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(orderedPrices, id: \.0) { entry in
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
