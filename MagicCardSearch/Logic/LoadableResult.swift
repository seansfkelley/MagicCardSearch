import Observation
import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "LoadableResult")

enum LoadableResult<T, E: Error> {
    case unloaded
    case loading(T?, E?)
    case loaded(T, E?)
    case errored(T?, E)
    
    var latestValue: T? {
        return switch self {
        case .unloaded: nil
        case .loading(let value, _): value
        case .loaded(let value, _): value
        case .errored(let value, _): value
        }
    }

    var latestError: E? {
        return switch self {
        case .unloaded: nil
        case .loading(_, let error): error
        case .loaded(_, let error): error
        case .errored(_, let error): error
        }
    }

    func mapValue<U>(_ transform: (T) -> U) -> LoadableResult<U, E> {
        return switch self {
        case .unloaded: .unloaded
        case .loading(let value, let error): .loading(value.map(transform), error)
        case .loaded(let value, let error): .loaded(transform(value), error)
        case .errored(let value, let error): .errored(value.map(transform), error)
        }
    }

    func asLoading(keepingData: Bool = true, keepingError: Bool = false) -> LoadableResult<T, E> {
        .loading(keepingData ? latestValue : nil, keepingError ? latestError : nil)
    }
    
    func asLoaded(_ data: T, keepingError: Bool = false) -> LoadableResult<T, E> {
        .loaded(data, keepingError ? latestError : nil)
    }
    
    func asErrored(_ error: E, keepingData: Bool = true) -> LoadableResult<T, E> {
        .errored(keepingData ? latestValue : nil, error)
    }

    @MainActor
    static func load(
        _ setter: (LoadableResult<T, any Error>) -> Void,
        _ initial: LoadableResult<T, any Error>? = nil,
        fetcher: @escaping () async throws -> T,
    ) async -> Void {
        setter(.loading(initial?.latestValue, initial?.latestError))
        do {
            let result = try await fetcher()
            setter(.loaded(result, nil))
        } catch {
            logger.error("error in LoadableResult.load error=\(error)")
            setter(.errored(initial?.latestValue, error))
        }
    }
}
