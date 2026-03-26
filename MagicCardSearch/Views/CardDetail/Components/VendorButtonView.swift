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

    var label: String {
        switch self {
        case .regular: "Regular"
        case .foil: "Foil"
        case .etched: "Etched"
        }
    }

    var icon: String? {
        switch self {
        case .regular: nil
        case .foil: "sparkles.2"
        case .etched: "sparkles.2"
        }
    }
}

struct VendorButtonView: View {
    @AppStorage("preferredVendor") private var preferredVendor: Vendor = .tcgplayer
    @Environment(\.openURL) private var openURL
    @State private var showingPopover = false

    let prices: Card.Prices
    let purchaseUris: [String: String]?

    private func orderedPrices(for vendor: Vendor) -> [(PriceType, String)] {
        [PriceType.regular, .foil, .etched].compactMap { type in
            vendor.price(from: prices, for: type).map { (type, $0) }
        }
    }

    var body: some View {
        Button { showingPopover = true } label: {
            let vendorPrices = orderedPrices(for: preferredVendor)
            HStack {
                Image(preferredVendor.rawValue)
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                if vendorPrices.isEmpty {
                    Text(preferredVendor.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                } else {
                    HStack(spacing: 6) {
                        ForEach(vendorPrices, id: \.0) { type, price in
                            HStack(spacing: 2) {
                                if let icon = type.icon {
                                    Image(systemName: icon)
                                        .font(.caption)
                                }
                                Text(preferredVendor.symbol + price)
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
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.1)))
        }
        .popover(isPresented: $showingPopover) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(Vendor.allCases.enumerated()), id: \.offset) { index, vendor in
                    VendorPopoverRow(
                        vendor: vendor,
                        prices: prices,
                        url: purchaseUris?[vendor.rawValue].flatMap { URL(string: $0) }
                    ) { url in
                        preferredVendor = vendor
                        if let url { openURL(url) }
                        showingPopover = false
                    }

                    if index < Vendor.allCases.count - 1 {
                        Divider()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .presentationCompactAdaptation(.popover)
        }
    }
}

private struct VendorPopoverRow: View {
    let vendor: Vendor
    let prices: Card.Prices
    let url: URL?
    let onTap: (URL?) -> Void

    private var orderedPrices: [(PriceType, String)] {
        [PriceType.regular, .foil, .etched].compactMap { type in
            vendor.price(from: prices, for: type).map { (type, $0) }
        }
    }

    var body: some View {
        Button { onTap(url) } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(vendor.rawValue)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 20)
                    Text(vendor.displayName)
                        .fontWeight(.medium)
                    if url != nil {
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !orderedPrices.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(orderedPrices, id: \.0) { type, price in
                            HStack(spacing: 3) {
                                Text(type.label)
                                    .foregroundStyle(.secondary)
                                Text(vendor.symbol + price)
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let prices = Card.Prices(tix: "0.05", usd: "1.23", usdFoil: "4.56", eur: "1.10", eurEtched: "2.20")
    let purchaseUris: [String: String] = [
        "tcgplayer": "https://www.tcgplayer.com",
        "cardmarket": "https://www.cardmarket.com",
        "cardhoarder": "https://www.cardhoarder.com",
    ]
    VendorButtonView(prices: prices, purchaseUris: purchaseUris)
        .padding()
}
