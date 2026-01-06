import SwiftUI
import ScryfallKit

struct SearchResultsGridView: View {
    let list: ScryfallObjectList<Card>

    @State private var selectedCardIndex: Int?
    @State private var cardFlipStates: [UUID: Bool] = [:]

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
                ContentUnavailableView(
                    "No Results",
                    systemImage: "circle.slash",
                )
            } else if let results = list.value.latestValue, !results.data.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        Text("\(results.totalCards ?? 0) \((results.totalCards ?? 0 == 1) ? "result" : "results")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 20)

                        LazyVGrid(columns: columns, spacing: spacing) {
                            ForEach(Array(results.data.enumerated()), id: \.element.id) { index, card in
                                CardView(
                                    card: card,
                                    quality: .normal,
                                    isFlipped: Binding(
                                        get: { cardFlipStates[card.id] ?? false },
                                        set: { cardFlipStates[card.id] = $0 }
                                    ),
                                    cornerRadius: 10,
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
        .sheet(
            item: Binding(
                get: { selectedCardIndex.map { IdentifiableIndex(index: $0) } },
                set: { selectedCardIndex = $0?.index }
            )
        ) { identifier in
            SearchResultsDetailNavigator(
                list: list,
                initialIndex: identifier.index,
                cardFlipStates: $cardFlipStates
            )
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
