//
//  Card+Extensions.swift
//  MagicCardSearch
//
//  Extensions to make ScryfallKit's Card easier to work with in views
//

import Foundation
import ScryfallKit

extension Card {
    static let aspectRatio: CGFloat = 0.716
    
    var releasedAtAsDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: releasedAt)
    }
    
    var bestEffortOracleId: String? {
        if let oracleId = oracleId {
            return oracleId
        } else if let faces = cardFaces {
            // TODO: There's got to be a map/filter/first version of this.
            for face in faces {
                if let oracleId = face.oracleId {
                    return oracleId
                }
            }
            return nil
        } else {
            return nil
        }
    }
    
    var primaryImageUris: Card.ImageUris? {
        if layout.isDoubleFaced {
            if let faces = cardFaces, !faces.isEmpty {
                return faces[0].imageUris
            }
        }
        return imageUris
    }
}
