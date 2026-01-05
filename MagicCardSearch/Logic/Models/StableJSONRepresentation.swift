import Foundation
import SQLiteData

// Forked from _CodableJSONRepresentation, since the JSON encoder there isn't configurable, to
// encode JSON in a representationally-stable manner so it can be unique'd on, not that that's a
// great idea in the first place.
// swiftlint:disable:next type_name
public struct _StableJSONRepresentation<QueryOutput: Codable>: Codable, QueryRepresentable, QueryBindable, QueryDecodable {
    public var queryOutput: QueryOutput

    public init(queryOutput: QueryOutput) {
        self.queryOutput = queryOutput
    }

    public var queryBinding: QueryBinding {
        do {
            return try .text(String(decoding: jsonEncoder.encode(queryOutput), as: UTF8.self))
        } catch {
            return .invalid(error)
        }
    }

    public init(decoder: inout some QueryDecoder) throws {
        self.init(
            queryOutput: try jsonDecoder.decode(
                QueryOutput.self,
                from: Data(String(decoder: &decoder).utf8)
            )
        )
    }
}

extension _StableJSONRepresentation: Equatable where QueryOutput: Equatable {}
extension _StableJSONRepresentation: Hashable where QueryOutput: Hashable {}
extension _StableJSONRepresentation: Sendable where QueryOutput: Sendable {}

// swiftlint:disable:next extension_access_modifier
extension Decodable where Self: Encodable {
  public typealias StableJSONRepresentation = _StableJSONRepresentation<Self>
}

// swiftlint:disable:next extension_access_modifier
extension Optional where Wrapped: Codable {
  public typealias StableJSONRepresentation = _StableJSONRepresentation<Wrapped>?
}

private let jsonDecoder: JSONDecoder = {
    var decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()

private let jsonEncoder: JSONEncoder = {
    var encoder = JSONEncoder()
    // This is what gives representational stability.
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}()
