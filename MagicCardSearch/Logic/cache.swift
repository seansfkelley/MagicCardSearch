import Foundation
import Cache
import SwiftUI

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
    ) ?? StrongMemoryStorage<Key, Value>(config: memory)
}

func uiImagePngTransformer() -> Transformer<UIImage> {
    return .init(
        toData: { img in
            guard let data = img.pngData() else {
                throw StorageError.transformerFail
            }
            return data
        },
        fromData: { data in
            guard let image = UIImage(data: data) else {
                throw StorageError.transformerFail
            }
            return image
        },
    )
}
