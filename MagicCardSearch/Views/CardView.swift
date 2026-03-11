import SwiftUI
import ScryfallKit
import NukeUI

extension Card {
    enum Orientation {
        case portrait, landscape, either
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
        if layout.isDoubleFaced, let faces = cardFaces, faces.count >= 1 {
            faces[0]
        } else {
            self
        }
    }
    var backFace: CardFaceDisplayable? {
        if layout.isDoubleFaced, let faces = cardFaces, faces.count >= 2 {
            faces[1]
        } else {
            nil
        }
    }

    var frontFaceOrientation: Orientation {
        if layout == .split {
            keywords.contains("Aftermath") ? .either : .landscape
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
    let card: CardDisplayable
    let quality: CardImageQuality
    @Binding var isFlipped: Bool
    let cornerRadius: CGFloat
    let showFlipButton: Bool

    init(
        card: CardDisplayable,
        quality: CardImageQuality,
        isFlipped: Binding<Bool>,
        cornerRadius: CGFloat,
        showFlipButton: Bool = true
    ) {
        self.card = card
        self.quality = quality
        self._isFlipped = isFlipped
        self.cornerRadius = cornerRadius
        self.showFlipButton = showFlipButton
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
                    showFlipButton: showFlipButton
                )
            } else {
                CardFaceView(
                    face: card.frontFace,
                    quality: quality,
                    cornerRadius: cornerRadius,
                )
            }
        }
        .aspectRatio(Card.aspectRatio, contentMode: .fit)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

private struct CardFaceView: View {
    let face: CardFaceDisplayable
    let quality: CardImageQuality
    let cornerRadius: CGFloat
    
    var body: some View {
        if let imageUrlString = quality.uri(from: face.imageUris),
           let url = URL(string: imageUrlString) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .contextMenu {
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
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                } else if state.error != nil {
                    CardPlaceholderView(name: face.name, cornerRadius: cornerRadius)
                } else {
                    CardPlaceholderView(name: face.name, cornerRadius: cornerRadius, with: .spinner)
                }
            }
        } else {
            CardPlaceholderView(name: face.name, cornerRadius: cornerRadius)
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
    
    var body: some View {
        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .centeredOnArt)) {
            ZStack {
                CardFaceView(
                    face: frontFace,
                    quality: quality,
                    cornerRadius: cornerRadius,
                )
                .opacity(isShowingBackFace ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isShowingBackFace ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
                
                CardFaceView(
                    face: backFace,
                    quality: quality,
                    cornerRadius: cornerRadius,
                )
                .opacity(isShowingBackFace ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isShowingBackFace ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0)
                )
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowingBackFace)
            .alignmentGuide(.centeredOnArt) { $0.height * 0.33 }
            
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
                .alignmentGuide(.centeredOnArt) { $0[VerticalAlignment.center] }
            }
        }
    }
}

// lightning bolt
// https://api.scryfall.com/cards/77c6fa74-5543-42ac-9ead-0e890b188e99
// life // death
// https://api.scryfall.com/cards/e16d52ca-f8de-4852-9bff-9d208e5f678f
// consign // oblivion
// https://api.scryfall.com/cards/1c1ead90-10d8-4217-80e4-6f40320c5569
// invasion of zendikar
// https://api.scryfall.com/cards/8fed056f-a8f5-41ec-a7d2-a80a238872d1

