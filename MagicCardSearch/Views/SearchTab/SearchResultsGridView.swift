import SwiftUI
import ScryfallKit

struct SearchResultsGridView: View {
    let list: ScryfallObjectList<Card>
    @Binding var searchState: SearchState
    
    @State private var selectedCardIndex: Int?
    @State private var cardFlipStates: [UUID: Bool] = [:]
    @State private var showSyntaxReference = false

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
                }
            } else if case .errored(nil, let error) = list.value {
                ContentUnavailableView {
                    Label(error.title, systemImage: error.iconName)
                } description: {
                    Text(error.description)
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
                                    selectedCardIndex = index
                                }
                                .onAppear {
                                    if index == results.data.count - 4 {
                                        list.loadNextPage()
                                    }
                                }
                                .padding(.horizontal, spacing / 2)
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
        .sheet(
            item: Binding(
                get: { selectedCardIndex.map { IdentifiableIndex(index: $0) } },
                set: { selectedCardIndex = $0?.index }
            )
        ) { identifier in
            NavigationStack {
                LazyPagingCardDetailNavigatorView(
                    list: list,
                    initialIndex: identifier.index,
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

#Preview {
    let list = ScryfallObjectList<Card> { page in
        try await ScryfallClient().searchCards(query: "color:izzet t:instant order:edhrec mv>=4", page: page)
    }
    PreviewContainer { searchState in
        SearchResultsGridView(list: list, searchState: searchState)
            .task { list.loadNextPage() }
    }
}
