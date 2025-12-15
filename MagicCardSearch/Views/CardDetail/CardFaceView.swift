//
//  CardFaceView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-11.
//
import SwiftUI
import NukeUI

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
        if let imageUrlString = CardImageQuality.bestQualityUri(from: face.imageUris),
           let url = URL(string: imageUrlString) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .contextMenu {
                            ShareLink(item: url, preview: SharePreview(face.name, image: image))
                            
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
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(0.7, contentMode: .fit)
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
