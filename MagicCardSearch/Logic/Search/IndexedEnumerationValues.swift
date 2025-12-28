//
//  IndexedEnumerationValues.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-27.
//
import Foundation

struct IndexedEnumerationValues<T: Sendable> {
    let sortedByLength: [T]
    let sortedAlphabetically: [T]

    init(_ values: [T], _ mapper: (T) -> String) {
        self.sortedByLength = values
            .map { ($0, mapper($0)) }
            .sorted(using: [
                KeyPathComparator(\.1.count),
                KeyPathComparator(\.1.self, comparator: .localizedStandard),
            ])
            .map { $0.0 }
        self.sortedAlphabetically = values
            .map { ($0, mapper($0)) }
            .sorted(using: [
                KeyPathComparator(\.1.self, comparator: .localizedStandard),
            ])
            .map { $0.0 }
    }
}

extension IndexedEnumerationValues where T == String {
    init(_ values: [T]) {
        self.init(values, \.self)
    }
}
