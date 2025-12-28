//
//  cardDetailSectionViews.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-13.
//
import SwiftUI
import ScryfallKit

// MARK: - Card Stat Section
struct CardStatSection: View {
    let value: String
    let label: String?
    
    init(value: String, label: String? = nil) {
        self.value = value
        self.label = label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                if let label = label {
                    Text("\(label):")
                        .font(.body)
                        .fontWeight(.semibold)
                }
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card Artist Section

struct CardArtistSection: View {
    let artist: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image("artist-nib")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                Text(artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card Legalities Section

struct CardLegalitiesSection: View {
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LegalityListView(card: card)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card Set Information Section

struct CardSetInfoSection: View {
    let setCode: String
    let setName: String
    let collectorNumber: String
    let rarity: Card.Rarity
    let lang: String
    let releasedAtAsDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                SetIconView(setCode: SetCode(setCode))

                VStack(alignment: .leading, spacing: 4) {
                    Text(setName)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    let suffix: String? = if let releaseDate = releasedAtAsDate {
                        releaseDate.formatted(.dateTime.year().month().day())
                    } else {
                        nil
                    }
                    
                    Text([
                        "\(setCode.uppercased()) #\(collectorNumber)",
                        rarity.rawValue.capitalized,
                        languageDisplay(for: lang),
                        suffix,
                    ].compactMap(\.self).joined(separator: " • ")
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func languageDisplay(for lang: String) -> String {
        let languages: [String: String] = [
            "en": "English",
            "es": "Spanish",
            "fr": "French",
            "de": "German",
            "it": "Italian",
            "pt": "Portuguese",
            "ja": "Japanese",
            "ko": "Korean",
            "ru": "Russian",
            "zhs": "Simplified Chinese",
            "zht": "Traditional Chinese",
            "he": "Hebrew",
            "la": "Latin",
            "grc": "Ancient Greek",
            "ar": "Arabic",
            "sa": "Sanskrit",
            "px": "Phyrexian",
        ]
        return languages[lang.lowercased()] ?? lang.capitalized
    }
}

// MARK: - Card Related Parts Section

struct CardRelatedPartsSection: View {
    let otherParts: [Card.RelatedCard]
    let isLoadingRelatedCard: Bool
    let onPartTapped: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Related Parts")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
                .padding(.vertical, 12)

            ForEach(otherParts.sorted { $0.name < $1.name }) { part in
                Button {
                    onPartTapped(part.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(part.name)
                                .font(.body)
                                .foregroundStyle(.primary)

                            Text(part.typeLine)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if isLoadingRelatedCard {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if part.id != otherParts.last?.id {
                    Divider()
                        .padding(.leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card Rulings Section

struct CardRulingsSection: View {
    let rulings: LoadableResult<[Card.Ruling], Error>
    let onRetry: () -> Void
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                if case .loading = rulings {
                    HStack {
                        Text("Loading rulings...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                } else if case .errored(_, let error) = rulings {
                    ContentUnavailableView {
                        Label("Failed to Load Rulings", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.localizedDescription)
                    } actions: {
                        Button("Try Again", action: onRetry)
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                    }
                } else {
                    ForEach(rulings.latestValue ?? []) { ruling in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(ruling.comment)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)

                            if let date = ruling.publishedAtAsDate {
                                Text(date, format: .dateTime.year().month().day())
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("Rulings")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
        }
        .tint(.primary)
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card Prices Section

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
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
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

// MARK: - Card Other Prints Section

struct CardAllPrintsSection: View {
    let oracleId: String
    let currentCardId: UUID

    @State private var showingPrintsSheet = false

    var body: some View {
        Button {
            showingPrintsSheet = true
        } label: {
            HStack {
                Text("All Prints")
                    .font(.headline)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingPrintsSheet) {
            CardAllPrintsView(oracleId: oracleId, initialCardId: currentCardId)
        }
    }
}
