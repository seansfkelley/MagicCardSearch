import SwiftUI
import ScryfallKit

struct SearchResultsGridView: View {
    let list: ScryfallObjectList<Card>
    @Binding var searchState: SearchState
    
    @State private var cardFlipStates: [UUID: Bool] = [:]
    @State private var showSyntaxReference = false
    @State private var selectedCardIndex: IdentifiableInt?

    private let spacing: CGFloat = 4

    private let columns = [
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0),
    ]

    var body: some View {
        ZStack {
            // TODO: Clean this up.
            if case .unloaded = list.value {
                EmptyView()
            } else if case .errored(let results, let error) = list.value, results?.data.isEmpty ?? true {
                ContentUnavailableView {
                    Label(error.title, systemImage: error.iconName)
                } description: {
                    Text(error.description)
                } actions: {
                    Button("Retry") {
                        searchState.retry()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            } else if case .errored(nil, let error) = list.value {
                ContentUnavailableView {
                    Label(error.title, systemImage: error.iconName)
                } description: {
                    Text(error.description)
                } actions: {
                    Button("Retry") {
                        searchState.retry()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            } else if case .loaded(let results, _) = list.value, results.data.isEmpty {
                ContentUnavailableView {
                    Label("No Results", systemImage: "rectangle.portrait.slash")
                } description: {
                    Text("Your search didn't match any cards.")
                } actions: {
                    Button {
                        showSyntaxReference = true
                    } label: {
                        Text("Syntax Reference")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            } else if let results = list.value.latestValue, !results.data.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        Text("^[\(results.totalCards ?? 0) result](inflect: true)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom)

                        LazyVGrid(columns: columns, spacing: spacing) {
                            ForEach(Array(results.data.enumerated()), id: \.element.id) { index, card in
                                CardView(
                                    card: card,
                                    quality: .normal,
                                    isFlipped: $cardFlipStates.for(card.id),
                                    cornerRadius: 10,
                                    enableCopyActions: true,
                                    enableZoomGestures: .pinchOnly,
                                    zoomGestureBasisAdjustment: 3.0,
                                )
                                .onTapGesture {
                                    selectedCardIndex = .init(index)
                                }
                                .onAppear {
                                    if index == results.data.count - 4 {
                                        list.loadNextPage()
                                    }
                                }
                                .padding(.horizontal, spacing / 2)
                                .overlay(alignment: .bottom) { overlaySortLabel(for: card) }
                            }
                        }

                        if (results.hasMore ?? false) || list.value.isLoadingNextPage || list.value.nextPageError != nil {
                            paginationStatusView
                                .padding(.horizontal)
                                .padding(.vertical, 20)
                        } else {
                            Text("Fin.")
                                .fontDesign(.serif)
                                .italic()
                                .foregroundStyle(.secondary)
                                .padding(.top)
                        }
                    }
                    .padding(.horizontal, spacing / 2)
                    .padding(.bottom)
                }
            }

            if list.value.isInitiallyLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)

                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: list.value.isInitiallyLoading)
        .sheet(isPresented: $showSyntaxReference) {
            NavigationStack {
                SyntaxReferenceView()
            }
        }
        .sheet(item: $selectedCardIndex) { index in
            NavigationStack {
                LazyPagingCardDetailNavigatorView(
                    list: list,
                    initialIndex: index.value,
                    cardFlipStates: $cardFlipStates,
                    searchState: $searchState,
                )
            }
        }
        .onChange(of: searchState.filters) {
            cardFlipStates = [:]
            selectedCardIndex = nil
        }
        .onChange(of: searchState.results?.value.latestValue?.data ?? []) { _, newValue in
            // This is a bit of a jank way to implement "auto-open on one search result" but it is
            // actually reliable. If the list changes for any reason, it can only end up with
            // length = 1 if a new search was initiated returning one result. Old searches only
            // grow larger as they page as there is no deletion, and pages are never going to be
            // count = 1.
            //
            // I would prefer a more explicit way to do this that e.g. hooks into the lifecycle of
            // a search action, but I designed the data types to obscure that and there's no good
            // way to observe the LoadableResult itself or the types near it changing, since none of
            // them are Equatable. Only the payload itself, [Card], is Equatable.
            if newValue.count == 1 {
                selectedCardIndex = 0
            }
        }
    }

    @ViewBuilder private func overlaySortLabel(for card: Card) -> some View {
        if searchState.configuration.showSortLabels,
           let (label, subtitleIcon) = card.overlaySortLabel(for: searchState.effectiveSortField) {
            HStack(spacing: 3) {
                if let icon = subtitleIcon?.image {
                    icon
                }
                Text(label)
            }
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
            .padding(6)
        }
    }

    @ViewBuilder private var paginationStatusView: some View {
        VStack(spacing: 16) {
            if list.value.isLoadingNextPage {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading more results...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else if let error = list.value.nextPageError {
                VStack(spacing: 16) {
                    Image(systemName: error.iconName)
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 4) {
                        Text(error.title)
                            .font(.headline)
                        Text(error.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button("Retry") {
                        list.loadNextPage()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            }
        }
    }
}

private enum SubtitleIcon {
    case foil, etched

    var image: Image {
        switch self {
        case .foil: Image(systemName: "sparkles")
        case .etched: Image("custom.sparkle.rectangle")
        }
    }
}

private extension Card {
    // swiftlint:disable:next cyclomatic_complexity
    func overlaySortLabel(for sortField: SearchConfiguration.SortField) -> (String, SubtitleIcon?)? {
        switch sortField {
        case .usd:
            let candidates: [(String?, SubtitleIcon?)] = [(prices.usd, nil), (prices.usdFoil, .foil), (prices.usdEtched, .etched)]
            guard let (price, kind) = candidates
                .compactMap({ (str, kind) in str.flatMap(Double.init).map { ($0, kind) } })
                .min(by: { $0.0 < $1.0 })
            else { return nil }
            return (String(format: "$%.2f", price), kind)
        case .eur:
            let candidates: [(String?, SubtitleIcon?)] = [(prices.eur, nil), (prices.eurFoil, .foil), (prices.eurEtched, .etched)]
            guard let (price, kind) = candidates
                .compactMap({ (str, kind) in str.flatMap(Double.init).map { ($0, kind) } })
                .min(by: { $0.0 < $1.0 })
            else { return nil }
            return (String(format: "€%.2f", price), kind)
        case .tix:
            guard let tix = prices.tix else { return nil }
            return ("\(tix) TIX", nil)
        case .edhrec:
            guard let edhrecRank else { return nil }
            return ("#\(edhrecRank)", nil)
        case .released:
            guard let label = PlainDate(from: releasedAt)?.formatted() else { return nil }
            return (label, nil)
        case .spoiled:
            guard let previewedAt = preview?.previewedAt,
                  let label = PlainDate(from: previewedAt)?.relativeLabel else { return nil }
            return (label, nil)
        case .name, .color, .set, .artist, .rarity, .power, .toughness, .cmc:
            return nil
        }
    }
}

#Preview {
    let list = ScryfallObjectList<Card> { page in
        try await CachingScryfallService.shared.searchCards(query: "color:izzet t:instant order:edhrec mv>=4", unique: .cards, order: nil, sortDirection: .auto, page: page)
    }
    PreviewContainer { searchState in
        SearchResultsGridView(list: list, searchState: searchState)
            .task { list.loadNextPage() }
    }
}
