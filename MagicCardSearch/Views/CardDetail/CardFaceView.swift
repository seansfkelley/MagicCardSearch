//
//  CardFaceView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-11.
//
import SwiftUI

struct CardFaceView: View {
    let face: CardFaceDisplayable
    let imageQuality: CardImageQuality
    
    init(
        face: CardFaceDisplayable,
        imageQuality: CardImageQuality = .normal,
    ) {
        self.face = face
        self.imageQuality = imageQuality
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
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
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
                case .failure:
                    CardPlaceholderView(name: face.name)
                @unknown default:
                    CardPlaceholderView(name: face.name)
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
