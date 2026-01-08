import Foundation
import OSLog
import SQLiteData

private let logger = Logger(subsystem: "MagicCardSearch", category: "TransformedBlob")

@propertyWrapper
class TransformedBlob<Value: Decodable> {
    @FetchOne private var blob: BlobEntry?
    private var key: String
    private var cache: Result<Value, Error>?
    private let transform: (Data) throws -> Value

    init(_ key: String, _ transform: @escaping (Data) throws -> Value) {
        self.key = key
        self._blob = FetchOne(wrappedValue: nil, BlobEntry.where { $0.key == key })
        self.transform = transform
    }

    init(_ key: String, withJsonDecoder jsonDecoder: JSONDecoder = JSONDecoder()) {
        self.key = key
        self._blob = FetchOne(wrappedValue: nil, BlobEntry.where { $0.key == key })
        self.transform = { try jsonDecoder.decode(Value.self, from: $0) }
    }

    var wrappedValue: Value? {
        if case .success(let value) = cache { return value }

        guard let blob else {
            return nil
        }

        do {
            let value = try transform(blob.value)
            cache = .success(value)
            return value
        } catch {
            logger.warning("failed to transform blob for key=\(self.key) error=\(error)")
            cache = .failure(error)
            return nil
        }
    }
}
