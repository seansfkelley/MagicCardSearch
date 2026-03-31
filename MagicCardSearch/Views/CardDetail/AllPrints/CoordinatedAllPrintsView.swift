import SwiftUI
import ScryfallKit

struct CoordinatedAllPrintsView: View {
    let cards: IndexedArray<Card>
    @Binding var currentId: UUID?
    let filterSettings: AllPrintsFilterSettings

    // It seems that these cannot share a position object, so we bridge between the two and,
    // unfortunately, also the binding from the parent.
    @State private var mainScrollPosition = ScrollPosition(idType: UUID.self)
    @State private var thumbnailScrollPosition = ScrollPosition(idType: UUID.self)
    @State private var partialScrollOffsetFraction: CGFloat = 0
    @State private var isFlipped: Bool = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                PagingCardImageView(
                    cards: cards,
                    scrollPosition: $mainScrollPosition,
                    partialScrollOffsetFraction: $partialScrollOffsetFraction,
                    screenWidth: geometry.size.width,
                    isFlipped: $isFlipped,
                    filterSettings: filterSettings,
                )

                ThumbnailPreviewStrip(
                    cards: cards,
                    scrollPosition: $thumbnailScrollPosition,
                    partialScrollOffsetFraction: partialScrollOffsetFraction,
                    screenWidth: geometry.size.width,
                    isFlipped: isFlipped
                )

                Spacer()

                if let currentId, let idx = cards.indexOf(id: currentId) {
                    Text("\(idx + 1) of \(cards.items.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: currentId, initial: true) {
            guard let currentId else { return }
            // These apparently-redundant checks prevent the view from snapping immediately between
            // items. I guess there's some kind of on-set behavior that overrides in-progress animations.
            if mainScrollPosition.viewID(type: UUID.self) != currentId {
                mainScrollPosition.scrollTo(id: currentId)
            }
            if thumbnailScrollPosition.viewID(type: UUID.self) != currentId {
                thumbnailScrollPosition.scrollTo(id: currentId)
            }
        }
        .onChange(of: mainScrollPosition.viewID(type: UUID.self)) { _, newCardId in
            if let newCardId, newCardId != currentId {
                currentId = newCardId
                // n.b. not animated because the calculated partial scroll offset thing makes sure
                // that the thumbnails are moving proportionally to the main view.
                if thumbnailScrollPosition.viewID(type: UUID.self) != newCardId {
                    // See next onChange for more on the redundancy of this with onChange(of: currentId).
                    thumbnailScrollPosition.scrollTo(id: newCardId)
                }
            }
        }
        .onChange(of: thumbnailScrollPosition.viewID(type: UUID.self)) { _, newCardId in
            if let newCardId, newCardId != currentId {
                currentId = newCardId
                // n.b. not animated to prevent excessive motion and potential image loads.
                if mainScrollPosition.viewID(type: UUID.self) != newCardId {
                    // Note that this is technically redundant with the onChange(of: currentId),
                    // which would be the "source of truth" for synchronization, however, that
                    // update pathway takes at least a full render cycle meaning that you can see a
                    // flicker of misplaced thumbnails when the offset flips suddently from -0.5 to
                    // +0.5.
                    mainScrollPosition.scrollTo(id: newCardId)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
    }
}

private extension AllPrintsFilterSettings.SortMode {
    var priceOrdering: [PriceType] {
        switch self {
        case .releaseDate, .regularPrice: .regularFirst
        case .foilPrice: .foilFirst
        }
    }
}

private struct PagingCardImageView: View {
    let cards: IndexedArray<Card>
    @Binding var scrollPosition: ScrollPosition
    @Binding var partialScrollOffsetFraction: CGFloat
    let screenWidth: CGFloat
    @Binding var isFlipped: Bool
    let filterSettings: AllPrintsFilterSettings

    @State private var scrollPhase: ScrollPhase = .idle
    @State private var cardWidth: CGFloat = 0

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(cards.items, id: \.id) { card in
                    VStack(alignment: .center, spacing: 0) {
                        // ZStack exists just to separate the padding from the GeometryReader so it
                        // can accurately see how large the card itself is.
                        ZStack {
                            CardView(
                                card: card,
                                quality: .large,
                                isFlipped: $isFlipped,
                                cornerRadius: 16,
                                enableCopyActions: true,
                                enableZoomGestures: .tapAndPinch,
                                zoomGestureBasisAdjustment: 1.2,
                            )
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .onChange(of: geometry.size.width, initial: true) {
                                            cardWidth = geometry.size.width
                                        }
                                }
                            )
                        }
                        .padding(.horizontal)

                        HStack(alignment: .center, spacing: 10) {
                            SetIconView(setCode: SetCode(card.set), size: 48)
                            VStack(alignment: .leading) {
                                HStack(alignment: .center) {
                                    Text("\(card.set.uppercased()) #\(card.collectorNumber)")
                                        .lineLimit(1)
                                    if !card.prices.isEmpty {
                                        // I originally had this as a ViewThatFits with 3>2>1
                                        // options but that absolutely fucking TANKED framerate, I
                                        // guess because of layout thrash. I pinned this to max=1
                                        // which is buttery smooth. Fixes I tried:
                                        //
                                        // - messing with .frame or .fixedSize in various places
                                        // - pushing ViewThatFits into VendorButtonView
                                        // - removing the GeometryReader above and just using
                                        //   constant padding
                                        //
                                        // Framerate still suffered in release builds.
                                        VendorButtonView(
                                            prices: card.prices,
                                            purchaseUris: card.purchaseUris,
                                            maxCount: 1,
                                            ordered: filterSettings.sort.priceOrdering,
                                        )
                                    }
                                }
                                HStack(spacing: 4) {
                                    if let date = card.releasedAtAsDate {
                                        Text("\(date.formatted(.dateTime.year().month().day()))")
                                        Text("•")
                                    }
                                    Text(card.setName).lineLimit(1).truncationMode(.middle)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical)
                        .padding(.horizontal, 4)
                        .frame(width: cardWidth)
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
        .onScrollPhaseChange { _, newPhase in
            scrollPhase = newPhase
            if newPhase != .interacting, newPhase != .decelerating {
                partialScrollOffsetFraction = 0
            }
        }
        .onScrollGeometryChange(
            for: CGFloat.self,
            of: { geometry in
                guard let currentId = scrollPosition.viewID(type: UUID.self),
                      let currentIndex = cards.indexOf(id: currentId) else {
                    return 0
                }
                return (CGFloat(currentIndex) * geometry.containerSize.width - geometry.contentOffset.x) / geometry.containerSize.width
            },
            action: { _, new in
                if scrollPhase == .interacting || scrollPhase == .decelerating {
                    partialScrollOffsetFraction = new
                }
            })
    }
}

private struct ThumbnailPreviewStrip: View {
    let cards: IndexedArray<Card>
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
                ForEach(cards.items, id: \.id) { card in
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
            .padding(.trailing, -partialScrollOffsetFraction * (thumbnailWidth + thumbnailSpacing))
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
