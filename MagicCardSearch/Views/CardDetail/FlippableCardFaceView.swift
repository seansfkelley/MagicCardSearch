//
//  FlipCardView.swift
//  MagicCardSearch
//
//  Reusable 3D flip card view for double-faced cards
//

import SwiftUI
import ScryfallKit

struct FlippableCardFaceView: View {
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
            ZStack {
                CardFaceView(
                    face: frontFace,
                    imageQuality: imageQuality,
                    aspectFit: aspectFit
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .opacity(showingBackFace ? 0 : 1)
                .rotation3DEffect(
                    .degrees(showingBackFace ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
                
                CardFaceView(
                    face: backFace,
                    imageQuality: imageQuality,
                    aspectFit: aspectFit
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
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
