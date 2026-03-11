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
}

@Observable
class StatefulLoadable<T> {
    public private(set) var value: LoadableResult<T, any Error> = .unloaded

    private let fetcher: () async throws -> T

    init(fetcher: @escaping () async throws -> T) {
        self.fetcher = fetcher
    }

    func load(force: Bool = false) async -> Void {
        if !force {
            if case .unloaded = value {
                // nop
            } else {
                return
            }
        }

        do {
            value = value.asLoading()
            let result = try await fetcher()
            value = .loaded(result, nil)
        } catch {
            value = .errored(value.latestValue, error)
            logger.error("error while loading StatefulLoadable error=\(error)")
        }
    }
}
