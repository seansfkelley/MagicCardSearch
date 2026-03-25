import SwiftUI
import ScryfallKit

struct CoordinatedAllPrintsView: View {
    let cards: [Card]
    @Binding var currentIndex: Int

    // It seems that these cannot share a position object, so we bridge between the two and,
    // unfortunately, also the currentIndex binding from the parent.
    @State private var mainScrollPosition = ScrollPosition(idType: UUID.self)
    @State private var thumbnailScrollPosition = ScrollPosition(idType: UUID.self)
    @State private var partialScrollOffsetFraction: CGFloat = 0
    @State private var isFlipped: Bool = false

    private var currentCard: Card? {
        guard currentIndex >= 0 && currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                PagingCardImageView(
                    cards: cards,
                    scrollPosition: $mainScrollPosition,
                    partialScrollOffsetFraction: $partialScrollOffsetFraction,
                    screenWidth: geometry.size.width,
                    isFlipped: $isFlipped
                )

                ThumbnailPreviewStrip(
                    cards: cards,
                    scrollPosition: $thumbnailScrollPosition,
                    partialScrollOffsetFraction: partialScrollOffsetFraction,
                    screenWidth: geometry.size.width,
                    isFlipped: isFlipped
                )

                Spacer()

                Text("\(currentIndex + 1) of \(cards.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if let currentCard {
                mainScrollPosition.scrollTo(id: currentCard.id)
                thumbnailScrollPosition.scrollTo(id: currentCard.id)
            }
        }
        .onChange(of: currentIndex) { _, newIndex in
            if let cardId = cards[safe: newIndex]?.id {
                if mainScrollPosition.viewID(type: UUID.self) != cardId {
                    mainScrollPosition.scrollTo(id: cardId)
                }
                if thumbnailScrollPosition.viewID(type: UUID.self) != cardId {
                    thumbnailScrollPosition.scrollTo(id: cardId)
                }
            }
        }
        .onChange(of: mainScrollPosition.viewID(type: UUID.self)) { _, newCardId in
            if let newCardId, let newIndex = cards.firstIndex(where: { $0.id == newCardId }), newIndex != currentIndex {
                currentIndex = newIndex
                // n.b. not animated because the calculated partial scroll offset thing makes sure
                // that the thumbnails are moving proportionally to the main view.
                if thumbnailScrollPosition.viewID(type: UUID.self) != newCardId {
                    thumbnailScrollPosition.scrollTo(id: newCardId)
                }
            }
        }
        .onChange(of: thumbnailScrollPosition.viewID(type: UUID.self)) { _, newCardId in
            if let newCardId, let newIndex = cards.firstIndex(where: { $0.id == newCardId }), newIndex != currentIndex {
                currentIndex = newIndex
                // n.b. not animated to prevent excessive motion and potential image loads.
                if mainScrollPosition.viewID(type: UUID.self) != newCardId {
                    mainScrollPosition.scrollTo(id: newCardId)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
    }
}

private struct PagingCardImageView: View {
    let cards: [Card]
    @Binding var scrollPosition: ScrollPosition
    @Binding var partialScrollOffsetFraction: CGFloat
    let screenWidth: CGFloat
    @Binding var isFlipped: Bool

    @State private var scrollPhase: ScrollPhase = .idle

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(cards, id: \.id) { card in
                    VStack(spacing: 0) {
                        CardView(
                            card: card,
                            quality: .large,
                            isFlipped: $isFlipped,
                            cornerRadius: 16,
                            enableZoomGestures: true,
                            enableCopyActions: true,
                        )
                        .padding(.horizontal)

                        SetMetadataCardSection(
                            setCode: card.set,
                            setName: card.setName,
                            collectorNumber: card.collectorNumber,
                            rarity: card.rarity,
                            lang: card.lang,
                            releasedAtAsDate: card.releasedAtAsDate,
                        )
                        .padding(.horizontal)

                        Group {
                            VendorButtonView(prices: card.prices, purchaseUris: card.purchaseUris)
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                    .frame(width: screenWidth)
                    .id(card.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition($scrollPosition, anchor: .center)
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(
            for: CGFloat.self,
            of: { geometry in
                guard let currentId = scrollPosition.viewID(type: UUID.self),
                      let currentIdx = cards.firstIndex(where: { $0.id == currentId }) else {
                    return 0
                }
                return (CGFloat(currentIdx) * geometry.containerSize.width - geometry.contentOffset.x) / geometry.containerSize.width
            },
            action: { _, new in
                partialScrollOffsetFraction = new
            })
    }
}

private struct ThumbnailPreviewStrip: View {
    let cards: [Card]
    @Binding var scrollPosition: ScrollPosition
    var partialScrollOffsetFraction: CGFloat
    let screenWidth: CGFloat
    var isFlipped: Bool

    private let thumbnailHeight: CGFloat = 100
    private let thumbnailSpacing: CGFloat = 8

    private var thumbnailWidth: CGFloat {
        thumbnailHeight * Card.aspectRatio
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: thumbnailSpacing) {
                ForEach(cards, id: \.id) { card in
                    CardView(
                        card: card,
                        quality: .small,
                        isFlipped: .constant(isFlipped),
                        cornerRadius: 4,
                        showFlipButton: false,
                    )
                    .scaleEffect(card.id == scrollPosition.viewID(type: UUID.self) ? 1.1 : 1.0)
                    // TODO: Enable this but only for the scale effect -- as written, it seems to animate the
                    // padding or otherwise cause whacko UI jitters.
                    // .animation(.easeOut(duration: 0.075), value: card.id == scrollPosition.viewID(type: UUID.self))
                    //
                    // Setting width here is crucial for the initial positioning; before the
                    // images have loaded, the LazyHStack doesn't know where to scroll to in
                    // order to show the initially-selected card. This should also help with
                    // pop-in of images on slow connections.
                    .frame(width: thumbnailWidth, height: thumbnailHeight)
                    .id(card.id)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollPosition.scrollTo(id: card.id)
                        }
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.leading, partialScrollOffsetFraction * (thumbnailWidth + thumbnailSpacing))
            .padding(.vertical, 12)
        }
        .contentMargins(.horizontal, (screenWidth - thumbnailWidth) / 2, for: .scrollContent)
        .scrollPosition($scrollPosition, anchor: .center)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .frame(height: thumbnailHeight + 16)
    }
}
