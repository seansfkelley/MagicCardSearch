//
//  CardResultCell.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-18.
//
import SwiftUI
import ScryfallKit
import NukeUI

protocol CardDisplayable {
    var frontFace: CardFaceDisplayable { get }
    var backFace: CardFaceDisplayable? { get }
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
                    CardPlaceholderView(name: face.name, cornerRadius: cornerRadius, withSpinner: true)
                }
            }
        } else {
            CardPlaceholderView(name: face.name, cornerRadius: cornerRadius)
        }
    }
}

struct CardPlaceholderView: View {
    let name: String?
    let cornerRadius: CGFloat
    let withSpinner: Bool
    
    init(name: String?, cornerRadius: CGFloat, withSpinner: Bool = false) {
        self.name = name
        self.cornerRadius = cornerRadius
        self.withSpinner = withSpinner
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(Card.aspectRatio, contentMode: .fit)
                .overlay(
                    VStack(spacing: 16) {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        
                        if let name {
                            Text(name)
                                .font(.title3)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding()
                )
            
            if withSpinner {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .aspectRatio(Card.aspectRatio, contentMode: .fit)
                    .background(Color(.systemGray6).opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
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
