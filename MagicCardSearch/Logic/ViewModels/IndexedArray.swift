import Observation

@Observable
final class IndexedArray<T: Identifiable> {
    public var items: [T] = []
    private var cachedIds: [T.ID] = []
    private var index: [T.ID: Int] = [:]

    func reindex(_ array: [T]) {
        guard cachedIds.count != array.count || !cachedIds.elementsEqual(array.lazy.map(\.id)) else {
            return
        }

        let ids = array.map(\.id)
        if ids != cachedIds {
            items = array
            cachedIds = ids
            index = Dictionary(uniqueKeysWithValues: zip(ids, ids.indices))
        }
    }

    func indexOf(id: T.ID) -> Int? {
        index[id]
    }

    func itemFor(id: T.ID) -> T? {
        index[id].flatMap { items[safe: $0] }
    }
}
