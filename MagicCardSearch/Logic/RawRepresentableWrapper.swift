import Foundation

// Having a value that is both Codable and RawRepresentable causes infinite recursion:
// https://stackoverflow.com/questions/74190477/app-crashes-when-setting-custom-struct-value-in-appstorage
//
// Per https://danielsaidi.com/blog/2023/08/23/storing-codable-types-in-swiftui-appstorage this type
// can be used to explicitly wrap any Codable and separate it from RawRepresentable. I tried to
// implement encode(to:) and init(from:) in an `extension Codable: RawRepresentable` (and other
// similar attempts) but the compiler wasn't have any of it, so I use this wrapper.
public struct RawRepresentableWrapper<Value: Codable>: RawRepresentable {
    public init(_ value: Value) {
        self.value = value
    }

    public init?(rawValue: String) {
        guard
            let data = rawValue.data(using: .utf8),
            let result = try? JSONDecoder().decode(Value.self, from: data)
        else { return nil }
        self = .init(result)
    }

    public var rawValue: String {
        guard
            let data = try? JSONEncoder().encode(value),
            let result = String(data: data, encoding: .utf8)
        else { return "" }
        return result
    }

    public var value: Value
}
