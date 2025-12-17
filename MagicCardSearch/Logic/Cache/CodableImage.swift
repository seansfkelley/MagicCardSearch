//
//  UIImage+Codable.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-17.
//

import UIKit

/// A wrapper that makes UIImage conform to Codable by converting to/from PNG data.
/// Based on implementation from https://github.com/hyperoslo/Cache
///
/// Note: We can't directly extend UIImage to conform to Codable because it's a non-final class
/// and we can't add required initializers in extensions. This wrapper provides a clean solution.
struct CodableImage: Codable, Sendable {
    let image: UIImage
    
    init(_ image: UIImage) {
        self.image = image
    }
    
    enum CodingKeys: String, CodingKey {
        case imageData
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let data = try container.decode(Data.self, forKey: .imageData)
        
        guard let image = UIImage(data: data) else {
            throw DecodingError.dataCorruptedError(
                forKey: .imageData,
                in: container,
                debugDescription: "Failed to create UIImage from data"
            )
        }
        
        self.image = image
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        guard let data = image.pngData() else {
            throw EncodingError.invalidValue(
                image,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Failed to convert UIImage to PNG data"
                )
            )
        }
        
        try container.encode(data, forKey: .imageData)
    }
}
// MARK: - UIImage Extensions

extension UIImage {
    /// Creates a codable wrapper for this image.
    var codable: CodableImage {
        CodableImage(self)
    }
}
