//
//  CardResultCell.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-18.
//
import SwiftUI
import ScryfallKit
import NukeUI

/// Protocol for types that can be displayed as a card face
protocol CardFaceDisplayable {
    var name: String { get }
    var typeLine: String? { get }
    var oracleText: String? { get }
    var flavorText: String? { get }
    var colorIndicator: [Card.Color]? { get }
    var power: String? { get }
    var toughness: String? { get }
    var loyalty: String? { get }
    var defense: String? { get }
    var artist: String? { get }
    var imageUris: Card.ImageUris? { get }
    
    // Properties that have differing types in ScryfallKit so need another name.
    var displayableManaCost: String { get }
}

// MARK: - Card.Face Conformance

extension Card.Face: CardFaceDisplayable {
    var displayableManaCost: String {
        return manaCost
    }
}

// MARK: - Card Conformance

extension Card: CardFaceDisplayable {
    var displayableManaCost: String {
        return manaCost ?? ""
    }
}

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
    let card: Card
    let quality: CardImageQuality
    @Binding var isFlipped: Bool
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if let faces = card.cardFaces, card.layout.isDoubleFaced && faces.count >= 2 {
                FlippableCardFaceView(
                    frontFace: faces[0],
                    backFace: faces[1],
                    quality: quality,
                    isShowingBackFace: $isFlipped,
                    cornerRadius: cornerRadius,
                )
            } else {
                CardFaceView(
                    face: card,
                    quality: quality,
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
        .aspectRatio(0.716, contentMode: .fit)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

private struct CardFaceView: View {
    let face: CardFaceDisplayable
    let quality: CardImageQuality
    
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
                } else if state.error != nil {
                    CardPlaceholderView(name: face.name)
                } else {
                    ZStack {
                        CardPlaceholderView(name: face.name)
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .aspectRatio(0.716, contentMode: .fit)
                            .background(Color(.systemGray6).opacity(0.4))
                    }
                }
            }
        } else {
            CardPlaceholderView(name: face.name)
        }
    }
}

private struct CardPlaceholderView: View {
    let name: String
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.2))
            .aspectRatio(0.7, contentMode: .fit)
            .overlay(
                VStack(spacing: 16) {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    
                    Text(name)
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            )
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
    
    var body: some View {
        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .centeredOnArt)) {
            ZStack {
                CardFaceView(
                    face: frontFace,
                    quality: quality,
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .opacity(isShowingBackFace ? 0 : 1)
                .rotation3DEffect(
                    .degrees(isShowingBackFace ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
                
                CardFaceView(
                    face: backFace,
                    quality: quality,
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .opacity(isShowingBackFace ? 1 : 0)
                .rotation3DEffect(
                    .degrees(isShowingBackFace ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0)
                )
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowingBackFace)
            .alignmentGuide(.centeredOnArt) { $0.height * 0.33 }
            
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
