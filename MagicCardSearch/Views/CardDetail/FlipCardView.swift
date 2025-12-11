//
//  FlipCardView.swift
//  MagicCardSearch
//
//  Reusable 3D flip card view for double-faced cards
//

import SwiftUI
import ScryfallKit

struct FlipCardView: View {
    let frontFace: CardFaceDisplayable
    let backFace: CardFaceDisplayable
    let imageQuality: CardImageQuality
    let aspectFit: Bool
    
    @State private var showingBackFace = false
    
    init(
        frontFace: CardFaceDisplayable,
        backFace: CardFaceDisplayable,
        imageQuality: CardImageQuality = .normal,
        aspectFit: Bool = true
    ) {
        self.frontFace = frontFace
        self.backFace = backFace
        self.imageQuality = imageQuality
        self.aspectFit = aspectFit
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // The 3D transforming views
            ZStack {
                CardFaceImageView(
                    face: frontFace,
                    imageQuality: imageQuality,
                    aspectFit: aspectFit
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(showingBackFace ? 0 : 1)
                .rotation3DEffect(
                    .degrees(showingBackFace ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
                
                CardFaceImageView(
                    face: backFace,
                    imageQuality: imageQuality,
                    aspectFit: aspectFit
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(showingBackFace ? 1 : 0)
                .rotation3DEffect(
                    .degrees(showingBackFace ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0)
                )
            }
            
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showingBackFace.toggle()
                }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(8)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
            .padding(8)
        }
    }
}

struct CardFaceImageView: View {
    let face: CardFaceDisplayable
    let imageQuality: CardImageQuality
    let aspectFit: Bool
    let showContextMenu: Bool
    
    init(
        face: CardFaceDisplayable,
        imageQuality: CardImageQuality = .normal,
        aspectFit: Bool = true,
        showContextMenu: Bool = false
    ) {
        self.face = face
        self.imageQuality = imageQuality
        self.aspectFit = aspectFit
        self.showContextMenu = showContextMenu
    }
    
    var body: some View {
        if let imageUrlString = imageQuality.imageUrl(from: face.imageUris),
           let url = URL(string: imageUrlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(0.7, contentMode: .fit)
                case .success(let image):
                    if showContextMenu {
                        image
                            .resizable()
                            .aspectRatio(contentMode: aspectFit ? .fit : .fill)
                            .contextMenu {
                                ShareLink(item: url, preview: SharePreview(face.name, image: image))
                                
                                Button {
                                    if let uiImage = ImageRenderer(content: image).uiImage {
                                        UIPasteboard.general.image = uiImage
                                    }
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            }
                    } else {
                        image
                            .resizable()
                            .aspectRatio(contentMode: aspectFit ? .fit : .fill)
                    }
                case .failure:
                    CardImagePlaceholder(name: face.name)
                @unknown default:
                    CardImagePlaceholder(name: face.name)
                }
            }
        } else {
            CardImagePlaceholder(name: face.name)
        }
    }
}

struct CardImagePlaceholder: View {
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
