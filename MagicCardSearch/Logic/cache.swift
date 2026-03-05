import Foundation
import Cache

func bestEffortCache<Key: Hashable>(
    memory: MemoryConfig,
    disk: DiskConfig,
) -> any StorageAware<Key, Data> {
    bestEffortCache(
        memory: memory,
        disk: disk,
        transformer: .init(toData: { x in x }, fromData: { x in x }),
    )
}

func bestEffortCache<Key: Hashable, Value>(
    memory: MemoryConfig,
    disk: DiskConfig,
    transformer: Transformer<Value>,
) -> any StorageAware<Key, Value> {
    (
        try? Storage(
            diskConfig: disk,
            memoryConfig: memory,
            fileManager: .default,
            transformer: transformer,
        )
    ) ?? MemoryStorage<Key, Value>(config: memory)
}
