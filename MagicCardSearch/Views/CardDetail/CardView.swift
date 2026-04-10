import SwiftUI
import ScryfallKit
import NukeUI

extension Card {
    enum Orientation {
        case portrait, landscape
        // TODO: When implemented, will require a lot of valid combinations for flippable faces.
        // case either
    }
}

protocol CardDisplayable {
    var frontFace: CardFaceDisplayable { get }
    var backFace: CardFaceDisplayable? { get }

    // It's hard to thread the necessary data to the face itself without implementing wrapper types,
    // so just keep it at the whole-card level.
    var frontFaceOrientation: Card.Orientation { get }
    var backFaceOrientation: Card.Orientation { get }
}

extension Card: CardDisplayable {
    var frontFace: CardFaceDisplayable {
        // Instead of enumerating which layouts are double-faced, which can get out of date, just
        // look at which faces actually have images to go with them. Physically single-sided cards
        // have the image URIs on the Card, whereas physically double-sided cards have them on each
        // face. This applies even for art series, ECL-style redundant-double-sided cards, and flip
        // cards.
        if let face = cardFaces?.first, face.imageUris != nil {
            face
        } else {
            self
        }
    }
    var backFace: CardFaceDisplayable? {
        // See above comment for logic.
        if let face = cardFaces?.second, face.imageUris != nil {
            face
        } else {
            nil
        }
    }

    var frontFaceOrientation: Orientation {
        if layout == .split {
            keywords.contains("Aftermath")
            ? .portrait // .either
            : .landscape
        } else if typeLine?.starts(with: "Battle ") ?? false {
            // While listed in the documentation, no cards actually have layout:battle, so we have
            // to inspect the type line instead.
            .landscape
        } else {
            .portrait
        }
    }

    var backFaceOrientation: Orientation {
        // I think this is it?
        layout == .meld ? .landscape : .portrait
    }
}

protocol CardFaceDisplayable {
    var name: String { get }
    var imageUris: Card.ImageUris? { get }
}

extension Card: CardFaceDisplayable {}
extension Card.Face: CardFaceDisplayable {}
extension BookmarkableCardFace: CardFaceDisplayable {}

// MARK: - Image Quality

enum CardImageQuality {
    case small
    case normal
    case large
    
    func uri(from: Card.ImageUris?) -> String? {
        switch self {
        case .small: from?.small
        case .normal: from?.normal
        case .large: from?.large
        }
    }
    
    static func bestQualityUri(from uris: Card.ImageUris?) -> String? {
        uris?.large ?? uris?.normal ?? uris?.small
    }
}

struct CardView: View {
    struct Placeholder: View {
        enum Decoration {
            case none, spinner
            case image(String)
            case action(String?, String, (String, () -> Void)?)
        }

        let name: String?
        let cornerRadius: CGFloat
        let decoration: Decoration

        init(name: String?, cornerRadius: CGFloat, with decoration: Decoration = .none) {
            self.name = name
            self.cornerRadius = cornerRadius
            self.decoration = decoration
        }

        var body: some View {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height

                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.gray.opacity(0.1))

                    VStack(spacing: 0) {
                        // Name bar
                        Text(name ?? " ")
                            .font(.system(size: height * 0.035, weight: .semibold))
                            .foregroundStyle(Color.gray.opacity(0.8))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, width * 0.02)
                            .padding(.vertical, height * 0.01)
                            .background(Color.gray.opacity(0.10), in: .rect(cornerRadius: height * 0.025, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: height * 0.025, style: .continuous).stroke(Color.gray.opacity(0.2), lineWidth: 2))
                            .padding(.horizontal, width * 0.04)
                            .padding(.top, width * 0.05)

                        // Art frame
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .overlay(alignment: .leading) { Color.gray.opacity(0.2).frame(width: 2) }
                            .overlay(alignment: .trailing) { Color.gray.opacity(0.2).frame(width: 2) }
                            .frame(height: height * 0.46)
                            .padding(.horizontal, width * 0.05)
                            .overlay {
                                switch decoration {
                                case .none:
                                    EmptyView()
                                case .image(let name):
                                    Image(systemName: name)
                                        .font(.system(size: width * 0.33))
                                        .foregroundStyle(Color(.systemGray3))
                                case .spinner:
                                    ProgressView()
                                        .controlSize(.large)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                                case .action(let icon, let description, let action):
                                    VStack(spacing: 12) {
                                        if let icon {
                                            Image(systemName: icon)
                                                .font(.system(size: width * 0.25))
                                                .foregroundStyle(Color(.systemGray3))
                                        }

                                        Text(description)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, width * 0.12)

                                        if let action {
                                            Button(action.0) { action.1() }
                                                .buttonStyle(.borderedProminent)
                                        }
                                    }
                                }
                            }

                        // Type line
                        Text(" ")
                            .font(.system(size: height * 0.035, weight: .semibold))
                            .foregroundStyle(Color.gray.opacity(0.5))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, width * 0.01)
                            .padding(.vertical, height * 0.01)
                            .background(Color.gray.opacity(0.10), in: .rect(cornerRadius: height * 0.025, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: height * 0.025, style: .continuous).stroke(Color.gray.opacity(0.2), lineWidth: 2))
                            .padding(.horizontal, width * 0.04)

                        // Text box
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .overlay(alignment: .leading) { Color.gray.opacity(0.2).frame(width: 2) }
                            .overlay(alignment: .trailing) { Color.gray.opacity(0.2).frame(width: 2) }
                            .overlay(alignment: .bottom) { Color.gray.opacity(0.2).frame(height: 2) }
                            .frame(height: height * 0.32)
                            .padding(.horizontal, width * 0.05)
                            .overlay(alignment: .topLeading) {
                                VStack(alignment: .leading, spacing: height * 0.02) {
                                    ForEach(0..<3, id: \.self) { i in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.gray.opacity(0.1))
                                            .frame(
                                                width: width * (i == 2 ? 0.5 : 0.8),
                                                height: height * 0.03
                                            )
                                    }
                                }
                                .padding(.leading, width * 0.1)
                                .padding(.top, height * 0.05)
                            }
                    }
                }
            }
            .aspectRatio(Card.aspectRatio, contentMode: .fit)
        }
    }

    let card: CardDisplayable
    let quality: CardImageQuality
    @Binding var isFlipped: Bool
    let cornerRadius: CGFloat
    let showFlipButton: Bool
    let enableCopyActions: Bool
    let enableZoomGestures: ZoomOverlayInitationGestures?
    let zoomGestureBasisAdjustment: CGFloat?

    init(
        card: CardDisplayable,
        quality: CardImageQuality,
        isFlipped: Binding<Bool>,
        cornerRadius: CGFloat,
        showFlipButton: Bool = true,
        enableCopyActions: Bool = false,
        enableZoomGestures: ZoomOverlayInitationGestures? = nil,
        zoomGestureBasisAdjustment: CGFloat? = nil,
    ) {
        self.card = card
        self.quality = quality
        self._isFlipped = isFlipped
        self.cornerRadius = cornerRadius
        self.showFlipButton = showFlipButton
        self.enableCopyActions = enableCopyActions
        self.enableZoomGestures = enableZoomGestures
        self.zoomGestureBasisAdjustment = zoomGestureBasisAdjustment
    }

    var body: some View {
        Group {
            if let backFace = card.backFace {
                FlippableCardFaceView(
                    frontFace: card.frontFace,
                    backFace: backFace,
                    frontFaceOrientation: card.frontFaceOrientation,
                    backFaceOrientation: card.backFaceOrientation,
                    quality: quality,
                    isShowingBackFace: $isFlipped,
                    cornerRadius: cornerRadius,
                    showFlipButton: showFlipButton,
                    enableCopyActions: enableCopyActions,
                    enableZoomGestures: enableZoomGestures,
                    zoomGestureBasisAdjustment: zoomGestureBasisAdjustment,
                )
            } else {
                CardFaceView(
                    face: card.frontFace,
                    orientation: card.frontFaceOrientation,
                    quality: quality,
                    cornerRadius: cornerRadius,
                    enableCopyActions: enableCopyActions,
                    enableZoomGestures: enableZoomGestures,
                    zoomGestureBasisAdjustment: zoomGestureBasisAdjustment,
                )
            }
        }
        .aspectRatio(Card.aspectRatio, contentMode: .fit)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

private struct CardFaceView: View {
    let face: CardFaceDisplayable
    let orientation: Card.Orientation
    let quality: CardImageQuality
    let cornerRadius: CGFloat
    let enableCopyActions: Bool
    let enableZoomGestures: ZoomOverlayInitationGestures?
    let zoomGestureBasisAdjustment: CGFloat?

    var body: some View {
        if let imageUrlString = quality.uri(from: face.imageUris),
           let url = URL(string: imageUrlString) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .if(enableZoomGestures) { view, gestures in
                            view.zoomOverlay(
                                for: state.imageContainer?.image,
                                clippingTo: AnyShape(RoundedRectangle(cornerRadius: cornerRadius)),
                                initatedWith: gestures,
                                zoomBasisAdjustment: zoomGestureBasisAdjustment ?? 1.0,
                            )
                        }
                        .if(enableCopyActions) { view in
                            view.contextMenu {
                                if let shareUrlString = CardImageQuality.bestQualityUri(from: face.imageUris),
                                   let url = URL(string: shareUrlString) {
                                    ShareLink(item: url, preview: SharePreview(face.name, image: image))
                                }

                                Button {
                                    if let container = state.imageContainer {
                                        UIPasteboard.general.image = container.image
                                    }
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            }
                        }
                } else if state.error != nil {
                    CardView.Placeholder(name: face.name, cornerRadius: cornerRadius)
                } else {
                    CardView.Placeholder(name: face.name, cornerRadius: cornerRadius, with: .spinner)
                }
            }
        } else {
            CardView.Placeholder(name: face.name, cornerRadius: cornerRadius)
        }
    }
}

private extension VerticalAlignment {
    struct CenteredOnArt: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context.height * 0.33 // empirical
        }
    }
    
    static let centeredOnArt = VerticalAlignment(CenteredOnArt.self)
}

private struct FlippableCardFaceView: View {
    let frontFace: CardFaceDisplayable
    let backFace: CardFaceDisplayable
    let frontFaceOrientation: Card.Orientation
    let backFaceOrientation: Card.Orientation
    let quality: CardImageQuality
    @Binding var isShowingBackFace: Bool
    let cornerRadius: CGFloat
    let showFlipButton: Bool
    let enableCopyActions: Bool
    let enableZoomGestures: ZoomOverlayInitationGestures?
    let zoomGestureBasisAdjustment: CGFloat?

    private var rotationAxis: (x: CGFloat, y: CGFloat, z: CGFloat) {
        (x: 0, y: 1, z: 0)
    }

    var body: some View {
        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .centeredOnArt)) {
            ZStack {
                CardFaceView(
                    face: frontFace,
                    orientation: frontFaceOrientation,
                    quality: quality,
                    cornerRadius: cornerRadius,
                    enableCopyActions: enableCopyActions,
                    enableZoomGestures: enableZoomGestures,
                    zoomGestureBasisAdjustment: zoomGestureBasisAdjustment,
                )
                .opacity(isShowingBackFace ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isShowingBackFace ? 180 : 0),
                    axis: rotationAxis,
                )

                CardFaceView(
                    face: backFace,
                    orientation: backFaceOrientation,
                    quality: quality,
                    cornerRadius: cornerRadius,
                    enableCopyActions: enableCopyActions,
                    enableZoomGestures: enableZoomGestures,
                    zoomGestureBasisAdjustment: zoomGestureBasisAdjustment,
                )
                .opacity(isShowingBackFace ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isShowingBackFace ? 0 : -180),
                    axis: rotationAxis,
                )
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowingBackFace)
            .alignmentGuide(.centeredOnArt) { $0.height * 0.37 }

            if showFlipButton {
                Button {
                    isShowingBackFace.toggle()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(8)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
            }
        }
    }
}

// MARK: - Previews

private struct PreviewCardFace: CardFaceDisplayable, Sendable {
    let name: String
    let imageUris: Card.ImageUris?
}

private struct PreviewCard: CardDisplayable, Sendable {
    private let _frontFace: PreviewCardFace
    private var _backFace: PreviewCardFace?
    var frontFaceOrientation: Card.Orientation
    var backFaceOrientation: Card.Orientation

    init(
        frontFace: PreviewCardFace,
        backFace: PreviewCardFace? = nil,
        frontFaceOrientation: Card.Orientation = .portrait,
        backFaceOrientation: Card.Orientation = .portrait,
    ) {
        self._frontFace = frontFace
        self._backFace = backFace
        self.frontFaceOrientation = frontFaceOrientation
        self.backFaceOrientation = backFaceOrientation
    }

    var frontFace: CardFaceDisplayable { _frontFace }
    var backFace: CardFaceDisplayable? { _backFace }
}

private extension PreviewCard {
    // Lightning Bolt (normal, single-faced)
    static let lightningBolt = PreviewCard(
        frontFace: PreviewCardFace(
            name: "Lightning Bolt",
            imageUris: .init(
                small: "https://cards.scryfall.io/small/front/7/7/77c6fa74-5543-42ac-9ead-0e890b188e99.jpg?1706239968",
                normal: "https://cards.scryfall.io/normal/front/7/7/77c6fa74-5543-42ac-9ead-0e890b188e99.jpg?1706239968",
                large: "https://cards.scryfall.io/large/front/7/7/77c6fa74-5543-42ac-9ead-0e890b188e99.jpg?1706239968",
                png: "https://cards.scryfall.io/png/front/7/7/77c6fa74-5543-42ac-9ead-0e890b188e99.png?1706239968",
                artCrop: "https://cards.scryfall.io/art_crop/front/7/7/77c6fa74-5543-42ac-9ead-0e890b188e99.jpg?1706239968",
                borderCrop: "https://cards.scryfall.io/border_crop/front/7/7/77c6fa74-5543-42ac-9ead-0e890b188e99.jpg?1706239968"
            )
        ),
    )

    // Life // Death (split, landscape)
    static let lifeAndDeath = PreviewCard(
        frontFace: PreviewCardFace(
            name: "Life // Death",
            imageUris: .init(
                small: "https://cards.scryfall.io/small/front/e/1/e16d52ca-f8de-4852-9bff-9d208e5f678f.jpg?1677291168",
                normal: "https://cards.scryfall.io/normal/front/e/1/e16d52ca-f8de-4852-9bff-9d208e5f678f.jpg?1677291168",
                large: "https://cards.scryfall.io/large/front/e/1/e16d52ca-f8de-4852-9bff-9d208e5f678f.jpg?1677291168",
                png: "https://cards.scryfall.io/png/front/e/1/e16d52ca-f8de-4852-9bff-9d208e5f678f.png?1677291168",
                artCrop: "https://cards.scryfall.io/art_crop/front/e/1/e16d52ca-f8de-4852-9bff-9d208e5f678f.jpg?1677291168",
                borderCrop: "https://cards.scryfall.io/border_crop/front/e/1/e16d52ca-f8de-4852-9bff-9d208e5f678f.jpg?1677291168"
            )
        ),
        frontFaceOrientation: .landscape,
    )

    // Consign // Oblivion (split with Aftermath, either orientation)
    static let consignAndOblivion = PreviewCard(
        frontFace: PreviewCardFace(
            name: "Consign // Oblivion",
            imageUris: .init(
                small: "https://cards.scryfall.io/small/front/1/c/1c1ead90-10d8-4217-80e4-6f40320c5569.jpg?1710406499",
                normal: "https://cards.scryfall.io/normal/front/1/c/1c1ead90-10d8-4217-80e4-6f40320c5569.jpg?1710406499",
                large: "https://cards.scryfall.io/large/front/1/c/1c1ead90-10d8-4217-80e4-6f40320c5569.jpg?1710406499",
                png: "https://cards.scryfall.io/png/front/1/c/1c1ead90-10d8-4217-80e4-6f40320c5569.png?1710406499",
                artCrop: "https://cards.scryfall.io/art_crop/front/1/c/1c1ead90-10d8-4217-80e4-6f40320c5569.jpg?1710406499",
                borderCrop: "https://cards.scryfall.io/border_crop/front/1/c/1c1ead90-10d8-4217-80e4-6f40320c5569.jpg?1710406499"
            )
        ),
        frontFaceOrientation: .portrait, // .either,
    )

    // Liliana, Heretical Healer // Liliana, Defiant Necromancer (transform, creature to planeswalker)
    static let liliana = PreviewCard(
        frontFace: PreviewCardFace(
            name: "Liliana, Heretical Healer",
            imageUris: .init(
                small: "https://cards.scryfall.io/small/front/d/8/d8b718d8-fca3-4b3e-9448-6067c8656a9a.jpg?1748260439",
                normal: "https://cards.scryfall.io/normal/front/d/8/d8b718d8-fca3-4b3e-9448-6067c8656a9a.jpg?1748260439",
                large: "https://cards.scryfall.io/large/front/d/8/d8b718d8-fca3-4b3e-9448-6067c8656a9a.jpg?1748260439",
                png: "https://cards.scryfall.io/png/front/d/8/d8b718d8-fca3-4b3e-9448-6067c8656a9a.png?1748260439",
                artCrop: "https://cards.scryfall.io/art_crop/front/d/8/d8b718d8-fca3-4b3e-9448-6067c8656a9a.jpg?1748260439",
                borderCrop: "https://cards.scryfall.io/border_crop/front/d/8/d8b718d8-fca3-4b3e-9448-6067c8656a9a.jpg?1748260439"
            )
        ),
        backFace: PreviewCardFace(
            name: "Liliana, Defiant Necromancer",
            imageUris: .init(
                small: "https://cards.scryfall.io/small/back/d/8/d8b718d8-fca3-4b3e-9448-6067c8656a9a.jpg?1748260439",
                normal: "https://cards.scryfall.io/normal/back/d/8/d8b718d8-fca3-4b3e-9448-6067c8656a9a.jpg?1748260439",
                large: "https://cards.scryfall.io/large/back/d/8/d8b718d8-fca3-4b3e-9448-6067c8656a9a.jpg?1748260439",
                png: "https://cards.scryfall.io/png/back/d/8/d8b718d8-fca3-4b3e-9448-6067c8656a9a.png?1748260439",
                artCrop: "https://cards.scryfall.io/art_crop/back/d/8/d8b718d8-fca3-4b3e-9448-6067c8656a9a.jpg?1748260439",
                borderCrop: "https://cards.scryfall.io/border_crop/back/d/8/d8b718d8-fca3-4b3e-9448-6067c8656a9a.jpg?1748260439"
            )
        ),
    )

    // Invasion of Zendikar // Awakened Skyclave (transform, double-faced)
    static let invasionOfZendikar = PreviewCard(
        frontFace: PreviewCardFace(
            name: "Invasion of Zendikar",
            imageUris: .init(
                small: "https://cards.scryfall.io/small/front/8/f/8fed056f-a8f5-41ec-a7d2-a80a238872d1.jpg?1739656250",
                normal: "https://cards.scryfall.io/normal/front/8/f/8fed056f-a8f5-41ec-a7d2-a80a238872d1.jpg?1739656250",
                large: "https://cards.scryfall.io/large/front/8/f/8fed056f-a8f5-41ec-a7d2-a80a238872d1.jpg?1739656250",
                png: "https://cards.scryfall.io/png/front/8/f/8fed056f-a8f5-41ec-a7d2-a80a238872d1.png?1739656250",
                artCrop: "https://cards.scryfall.io/art_crop/front/8/f/8fed056f-a8f5-41ec-a7d2-a80a238872d1.jpg?1739656250",
                borderCrop: "https://cards.scryfall.io/border_crop/front/8/f/8fed056f-a8f5-41ec-a7d2-a80a238872d1.jpg?1739656250"
            )
        ),
        backFace: PreviewCardFace(
            name: "Awakened Skyclave",
            imageUris: .init(
                small: "https://cards.scryfall.io/small/back/8/f/8fed056f-a8f5-41ec-a7d2-a80a238872d1.jpg?1739656250",
                normal: "https://cards.scryfall.io/normal/back/8/f/8fed056f-a8f5-41ec-a7d2-a80a238872d1.jpg?1739656250",
                large: "https://cards.scryfall.io/large/back/8/f/8fed056f-a8f5-41ec-a7d2-a80a238872d1.jpg?1739656250",
                png: "https://cards.scryfall.io/png/back/8/f/8fed056f-a8f5-41ec-a7d2-a80a238872d1.png?1739656250",
                artCrop: "https://cards.scryfall.io/art_crop/back/8/f/8fed056f-a8f5-41ec-a7d2-a80a238872d1.jpg?1739656250",
                borderCrop: "https://cards.scryfall.io/border_crop/back/8/f/8fed056f-a8f5-41ec-a7d2-a80a238872d1.jpg?1739656250"
            )
        ),
        frontFaceOrientation: .landscape,
    )

    // Invalid (no image URIs)
    static let invalid = PreviewCard(
        frontFace: PreviewCardFace(name: "Invalid Card", imageUris: nil)
    )
}


#Preview("Placeholders") {
    ScrollView {
        VStack {
            CardView.Placeholder(
                name: nil,
                cornerRadius: 16,
                with: .none,
            )
            CardView.Placeholder(
                name: nil,
                cornerRadius: 16,
                with: .image("shuffle"),
            )
            CardView.Placeholder(
                name: "Lightning Bolt",
                cornerRadius: 16,
                with: .spinner,
            )
            CardView.Placeholder(
                name: "Lightning Bolt",
                cornerRadius: 16,
                with: .action("exclamationmark.triangle", "Could not connect to Scryfall.", nil),
            )
            CardView.Placeholder(
                name: "Lightning Bolt",
                cornerRadius: 16,
                with: .action(
                    "exclamationmark.triangle",
                    "The Internet connection appears to be offline.",
                    ("Retry", {}),
                ),
            )
        }
        .padding()
    }
}

#Preview("Lightning Bolt") {
    @Previewable @State var isFlipped = false
    CardView(card: PreviewCard.lightningBolt, quality: .normal, isFlipped: $isFlipped, cornerRadius: 12)
        .frame(width: 300)
        .padding()
}

#Preview("Life // Death") {
    @Previewable @State var isFlipped = false
    CardView(card: PreviewCard.lifeAndDeath, quality: .normal, isFlipped: $isFlipped, cornerRadius: 12)
        .frame(width: 300)
        .padding()
}

#Preview("Consign // Oblivion") {
    @Previewable @State var isFlipped = false
    CardView(card: PreviewCard.consignAndOblivion, quality: .normal, isFlipped: $isFlipped, cornerRadius: 12)
        .frame(width: 300)
        .padding()
}

#Preview("Liliana, Heretical Healer") {
    @Previewable @State var isFlipped = false
    CardView(card: PreviewCard.liliana, quality: .normal, isFlipped: $isFlipped, cornerRadius: 12)
        .frame(width: 300)
        .padding()
}

#Preview("Invasion of Zendikar") {
    @Previewable @State var isFlipped = false
    CardView(card: PreviewCard.invasionOfZendikar, quality: .normal, isFlipped: $isFlipped, cornerRadius: 12)
        .frame(width: 300)
        .padding()
}

#Preview("Invalid") {
    @Previewable @State var isFlipped = false
    CardView(card: PreviewCard.invalid, quality: .normal, isFlipped: $isFlipped, cornerRadius: 12)
        .frame(width: 300)
        .padding()
}
