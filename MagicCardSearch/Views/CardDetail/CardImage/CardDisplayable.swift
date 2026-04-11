import SwiftUI
import ScryfallKit

protocol CardDisplayable {
    var frontFace: CardFaceDisplayable { get }
    var backFace: CardFaceDisplayable? { get }

    // It's hard to thread the necessary data to the face itself without implementing wrapper types,
    // so just keep it at the whole-card level.
    var frontFaceOrientation: Card.Orientation { get }
    var backFaceOrientation: Card.Orientation { get }
}

protocol CardFaceDisplayable {
    var name: String { get }
    var imageUris: Card.ImageUris? { get }
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
        } else if layout == .meld {
            MeldBackFace(self)
        } else {
            nil
        }
    }

    var frontFaceOrientation: Orientation {
        if layout == .flip {
            .flip
        } else if layout == .split {
            keywords.contains("Aftermath")
            ? .either(.counterclockwise)
            : .landscape(.clockwise)
        } else if typeLine?.starts(with: "Battle ") ?? false {
            // While listed in the documentation, no cards actually have layout:battle, so we have
            // to inspect the type line instead.
            .landscape(.clockwise)
        } else {
            .portrait
        }
    }

    var backFaceOrientation: Orientation {
        // I think this is the only current case for a non-portrait back face.
        layout == .meld ? .landscape(.counterclockwise) : .portrait
    }
}

extension Card: CardFaceDisplayable {}
extension Card.Face: CardFaceDisplayable {}
extension BookmarkableCardFace: CardFaceDisplayable {}

private struct MeldBackFace: CardFaceDisplayable {
    let name: String
    let imageUris: Card.ImageUris?

    init(_ card: Card) {
        self.name = card.allParts?.first(where: { $0.component == .meldResult })?.name ?? card.name
        guard let backId = card.cardBackId else {
            self.imageUris = nil
            return
        }
        let uuidStr = backId.uuidString.lowercased()
        let a = uuidStr.prefix(1)
        let b = uuidStr.dropFirst().prefix(1)
        self.imageUris = Card.ImageUris(
            small: "https://backs.scryfall.io/small/\(a)/\(b)/\(uuidStr).jpg",
            normal: "https://backs.scryfall.io/normal/\(a)/\(b)/\(uuidStr).jpg",
            large: "https://backs.scryfall.io/large/\(a)/\(b)/\(uuidStr).jpg",
            png: "https://backs.scryfall.io/png/\(a)/\(b)/\(uuidStr).png",
            artCrop: "https://backs.scryfall.io/art_crop/\(a)/\(b)/\(uuidStr).jpg",
            borderCrop: "https://backs.scryfall.io/border_crop/\(a)/\(b)/\(uuidStr).jpg",
        )
    }
}
