import SwiftUI
import ScryfallKit
import NukeUI

struct LazyCardImageView: View {
    let face: CardFaceDisplayable
    let quality: CardImageQuality
    let cornerRadius: CGFloat
    let enableCopyActions: Bool
    let enableZoomGestures: ZoomOverlayInitationGestures?
    let zoomGestureBasisAdjustment: CGFloat?

    var body: some View {
        Group {
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
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    } else if state.error != nil {
                        CardImageView.Placeholder(name: face.name, cornerRadius: cornerRadius)
                    } else {
                        CardImageView.Placeholder(name: face.name, cornerRadius: cornerRadius, with: .spinner)
                    }
                }
            } else {
                CardImageView.Placeholder(name: face.name, cornerRadius: cornerRadius)
            }
        }
        .aspectRatio(Card.aspectRatio, contentMode: .fit)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
