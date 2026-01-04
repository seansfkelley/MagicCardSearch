import ScryfallKit

protocol AnyObjectList {
    associatedtype Element
    var data: [Element] { get }
}

extension ObjectList: AnyObjectList {}

extension LoadableResult where T: AnyObjectList {
    var isInitiallyLoading: Bool {
        if case .loading(let value, _) = self, value == nil {
            return true
        }
        return false
    }
    
    var isLoadingNextPage: Bool {
        if case .loading(let value, _) = self, value != nil {
            return true
        }
        return false
    }
    
    var nextPageError: E? {
        if case .errored(let value, let error) = self, (value?.data.count ?? 0) > 0 {
            return error
        }
        return nil
    }
}
