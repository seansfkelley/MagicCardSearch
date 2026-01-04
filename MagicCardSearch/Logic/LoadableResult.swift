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
