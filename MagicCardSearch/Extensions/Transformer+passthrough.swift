import Foundation
import Cache

extension Transformer {
    static var passthrough: Transformer<Data> {
        .init(toData: { x in x }, fromData: { x in x })
    }
}
