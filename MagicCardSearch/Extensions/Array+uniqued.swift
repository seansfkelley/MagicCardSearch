extension Array {
    func uniqued<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { element in
            let key = element[keyPath: keyPath]
            if seen.contains(key) {
                return false
            } else {
                seen.insert(key)
                return true
            }
        }
    }
    
    func uniqued<T: Hashable>(by keyPath: KeyPath<Element, T?>) -> [Element] {
        var seen = Set<T>()
        return filter { element in
            guard let key = element[keyPath: keyPath] else {
                return true
            }
            
            if seen.contains(key) {
                return false
            } else {
                seen.insert(key)
                return true
            }
        }
    }
    
    func uniqued<T: Hashable>(by transform: (Element) -> T) -> [Element] {
        var seen = Set<T>()
        return filter { element in
            let key = transform(element)
            if seen.contains(key) {
                return false
            } else {
                seen.insert(key)
                return true
            }
        }
    }
    
    func uniqued<T: Hashable>(by transform: (Element) -> T?) -> [Element] {
        var seen = Set<T>()
        return filter { element in
            guard let key = transform(element) else {
                return true
            }
            
            if seen.contains(key) {
                return false
            } else {
                seen.insert(key)
                return true
            }
        }
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { element in
            if seen.contains(element) {
                return false
            } else {
                seen.insert(element)
                return true
            }
        }
    }
}
