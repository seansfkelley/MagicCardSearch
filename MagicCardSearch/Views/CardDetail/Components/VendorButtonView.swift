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

    var currency: String {
        switch self {
        case .tcgplayer: "USD"
        case .cardmarket: "EUR"
        case .cardhoarder: "TIX"
        }
    }

    var image: Image { Image(rawValue) }

    var blueImage: Image { Image("\(rawValue)-blue") }

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
        case .regular: "Reg."
        case .foil: "Foil"
        case .etched: "Etched"
        }
    }

    var image: Image? {
        switch self {
        case .regular: nil
        case .foil: Image(systemName: "sparkles")
        case .etched: Image("custom.sparkle.rectangle")
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
        [.regular, .foil, .etched].compactMap { type in
            vendor.price(from: prices, for: type).map { (type, $0) }
        }
    }

    var body: some View {
        Button { showingPopover = true } label: {
            let vendorPrices = orderedPrices(for: preferredVendor)
            HStack {
                if vendorPrices.isEmpty {
                    Text("No \(preferredVendor.currency) Price")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                } else {
                    HStack(spacing: 12) {
                        ForEach(vendorPrices, id: \.0) { type, price in
                            HStack(spacing: 2) {
                                if let image = type.image {
                                    image
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
                    let url = purchaseUris?[vendor.rawValue].flatMap { URL(string: $0) }
                    let prices = orderedPrices(for: vendor)

                    if url != nil || !prices.isEmpty {
                        VendorPopoverRow(
                            vendor: vendor,
                            orderedPrices: prices,
                            showUrlIcon: url != nil,
                        ) {
                            preferredVendor = vendor
                            if let url { openURL(url) }
                            showingPopover = false
                        }

                        if index < Vendor.allCases.count - 1 {
                            Divider()
                        }
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
    let orderedPrices: [(PriceType, String)]
    let showUrlIcon: Bool
    let onTap: () -> Void

    var body: some View {
        Button { onTap() } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        vendor.image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 16)

                        Text(vendor.displayName)
                            .fontWeight(.medium)
                    }

                    if !orderedPrices.isEmpty {
                        HStack(spacing: 10) {
                            ForEach(orderedPrices, id: \.0) { type, price in
                                HStack(spacing: 3) {
                                    Text(type.label)
                                        .foregroundStyle(.secondary)
                                    Text(vendor.symbol + price)
                                }
                                .font(.subheadline)
                            }
                        }
                    }
                }

                if showUrlIcon {
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .foregroundStyle(.secondary)
                        .frame(height: 32)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @AppStorage("preferredVendor") var preferredVendor: Vendor = .tcgplayer
    let allVendorUris: [String: String] = [
        "tcgplayer": "https://www.tcgplayer.com",
        "cardmarket": "https://www.cardmarket.com",
        "cardhoarder": "https://www.cardhoarder.com",
    ]
    VStack(alignment: .leading, spacing: 16) {
        Picker("Preferred Vendor", selection: $preferredVendor) {
            ForEach(Vendor.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
        .pickerStyle(.segmented)

        Text("All vendors")
        VendorButtonView(
            prices: Card.Prices(tix: "0.05", usd: "1.23", usdFoil: "4.56", eur: "1.10", eurEtched: "2.20"),
            purchaseUris: allVendorUris
        )

        Text("TCGplayer only")
        VendorButtonView(
            prices: Card.Prices(usd: "1.23"),
            purchaseUris: ["tcgplayer": "https://www.tcgplayer.com"]
        )

        Text("Cardmarket only")
        VendorButtonView(
            prices: Card.Prices(eur: "1.10"),
            purchaseUris: ["cardmarket": "https://www.cardmarket.com"]
        )

        Text("Cardhoarder only")
        VendorButtonView(
            prices: Card.Prices(tix: "0.05"),
            purchaseUris: ["cardhoarder": "https://www.cardhoarder.com"]
        )

        Text("No prices, yes URIs")
        VendorButtonView(prices: Card.Prices(), purchaseUris: allVendorUris)

        Text("No prices, no URIs")
        VendorButtonView(prices: Card.Prices(), purchaseUris: nil)

        Text("Foil only")
        VendorButtonView(
            prices: Card.Prices(usdFoil: "4.56", eurFoil: "3.80"),
            purchaseUris: ["tcgplayer": "https://www.tcgplayer.com", "cardmarket": "https://www.cardmarket.com"]
        )
    }
    .padding()
}
