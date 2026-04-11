import SwiftUI
import ScryfallKit

struct CardImageView: View {
    enum FaceTransforms {
        case none, portrait, all
    }

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
    let cornerRadius: CGFloat
    @Binding var isShowingBackFace: Bool
    let enableTransforms: FaceTransforms
    let enableCopyActions: Bool
    let enableZoomGestures: ZoomOverlayInitationGestures?
    let zoomGestureBasisAdjustment: CGFloat?

    init(
        card: CardDisplayable,
        quality: CardImageQuality,
        cornerRadius: CGFloat,
        isShowingBackFace: Binding<Bool> = .constant(false),
        enableTransforms: FaceTransforms = .none,
        enableCopyActions: Bool = false,
        enableZoomGestures: ZoomOverlayInitationGestures? = nil,
        zoomGestureBasisAdjustment: CGFloat? = nil,
    ) {
        self.card = card
        self.quality = quality
        self.cornerRadius = cornerRadius
        self._isShowingBackFace = isShowingBackFace
        self.enableTransforms = enableTransforms
        self.enableCopyActions = enableCopyActions
        self.enableZoomGestures = enableZoomGestures
        self.zoomGestureBasisAdjustment = zoomGestureBasisAdjustment
    }

    var body: some View {
        if let backFace = card.backFace {
            DoubleFacedCardImageView(
                frontFace: card.frontFace,
                backFace: backFace,
                frontFaceOrientation: card.frontFaceOrientation,
                backFaceOrientation: card.backFaceOrientation,
                quality: quality,
                isShowingBackFace: $isShowingBackFace,
                cornerRadius: cornerRadius,
                enableTransforms: enableTransforms,
                enableCopyActions: enableCopyActions,
                enableZoomGestures: enableZoomGestures,
                zoomGestureBasisAdjustment: zoomGestureBasisAdjustment,
            )
        } else {
            SingleFacedCardImageView(
                face: card.frontFace,
                orientation: card.frontFaceOrientation,
                quality: quality,
                cornerRadius: cornerRadius,
                enableTransforms: enableTransforms,
                enableCopyActions: enableCopyActions,
                enableZoomGestures: enableZoomGestures,
                zoomGestureBasisAdjustment: zoomGestureBasisAdjustment,
            )
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
        frontFaceOrientation: .landscape(.clockwise),
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
        frontFaceOrientation: .either(.counterclockwise),
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
        frontFaceOrientation: .landscape(.clockwise),
    )

    static let homuraHumanAscendant = PreviewCard(
        frontFace: PreviewCardFace(
            name: "Homura, Human Ascendant",
            imageUris: .init(
                small: "https://cards.scryfall.io/small/front/8/4/84920a21-ee2a-41ac-a369-347633d10371.jpg?1562494702",
                normal: "https://cards.scryfall.io/normal/front/8/4/84920a21-ee2a-41ac-a369-347633d10371.jpg?1562494702",
                large: "https://cards.scryfall.io/large/front/8/4/84920a21-ee2a-41ac-a369-347633d10371.jpg?1562494702",
                png: "https://cards.scryfall.io/png/front/8/4/84920a21-ee2a-41ac-a369-347633d10371.png?1562494702",
                artCrop: "https://cards.scryfall.io/art_crop/front/8/4/84920a21-ee2a-41ac-a369-347633d10371.jpg?1562494702",
                borderCrop: "https://cards.scryfall.io/border_crop/front/8/4/84920a21-ee2a-41ac-a369-347633d10371.jpg?1562494702"
            )
        ),
        frontFaceOrientation: .flip,
    )

    // Invalid (no image URIs)
    static let invalid = PreviewCard(
        frontFace: PreviewCardFace(name: "Invalid Card", imageUris: nil)
    )
}

#Preview("Placeholders") {
    ScrollView {
        VStack {
            CardImageView.Placeholder(
                name: nil,
                cornerRadius: 16,
                with: .none,
            )
            CardImageView.Placeholder(
                name: nil,
                cornerRadius: 16,
                with: .image("shuffle"),
            )
            CardImageView.Placeholder(
                name: "Lightning Bolt",
                cornerRadius: 16,
                with: .spinner,
            )
            CardImageView.Placeholder(
                name: "Lightning Bolt",
                cornerRadius: 16,
                with: .action("exclamationmark.triangle", "Could not connect to Scryfall.", nil),
            )
            CardImageView.Placeholder(
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
    @Previewable @State var isShowingBackFace = false
    CardImageView(
        card: PreviewCard.lightningBolt,
        quality: .normal,
        cornerRadius: 12,
        isShowingBackFace: $isShowingBackFace,
        enableTransforms: .all,
    )
        .frame(width: 300)
        .padding()
}

#Preview("Life // Death") {
    @Previewable @State var isShowingBackFace = false
    CardImageView(
        card: PreviewCard.lifeAndDeath,
        quality: .normal,
        cornerRadius: 12,
        isShowingBackFace: $isShowingBackFace,
        enableTransforms: .all,
    )
        .frame(width: 300)
        .padding()
}

#Preview("Consign // Oblivion") {
    @Previewable @State var isShowingBackFace = false
    CardImageView(
        card: PreviewCard.consignAndOblivion,
        quality: .normal,
        cornerRadius: 12,
        isShowingBackFace: $isShowingBackFace,
        enableTransforms: .all,
    )
        .frame(width: 300)
        .padding()
}

#Preview("Liliana, Heretical Healer") {
    @Previewable @State var isShowingBackFace = false
    CardImageView(
        card: PreviewCard.liliana,
        quality: .normal,
        cornerRadius: 12,
        isShowingBackFace: $isShowingBackFace,
        enableTransforms: .all,
    )
        .frame(width: 300)
        .padding()
}

#Preview("Invasion of Zendikar") {
    @Previewable @State var isShowingBackFace = false
    CardImageView(
        card: PreviewCard.invasionOfZendikar,
        quality: .normal,
        cornerRadius: 12,
        isShowingBackFace: $isShowingBackFace,
        enableTransforms: .all,
    )
        .frame(width: 300)
        .padding()
}

#Preview("Invalid") {
    @Previewable @State var isShowingBackFace = false
    CardImageView(
        card: PreviewCard.invalid,
        quality: .normal,
        cornerRadius: 12,
        isShowingBackFace: $isShowingBackFace,
        enableTransforms: .all,
    )
        .frame(width: 300)
        .padding()
}
