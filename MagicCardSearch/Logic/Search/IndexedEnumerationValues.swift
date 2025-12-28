//
//  IndexedEnumerationValues.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-27.
//
import Foundation
import Algorithms

struct IndexedEnumerationValues<T: Sendable> {
    enum Sort {
        case alphabetical
        case length
    }

    struct Match<U> {
        let value: U
        let string: String
        let range: Range<String.Index>
    }

    private let sortedByLength: [(String, T)]
    private let sortedAlphabetically: [(String, T)]

    init(_ values: [T], _ mapper: (T) -> String) {
        self.sortedByLength = values
            .map { (mapper($0), $0) }
            .sorted(using: [
                KeyPathComparator(\.0.count),
                KeyPathComparator(\.0.self, comparator: .localizedStandard),
            ])
        self.sortedAlphabetically = values
            .map { (mapper($0), $0) }
            .sorted(using: [
                KeyPathComparator(\.0.self, comparator: .localizedStandard),
            ])
    }

    func matching(prefix: String, sortingBy sort: Sort = .alphabetical) -> any Sequence<Match<T>> {
        var matches: ArraySlice<(String, T)>
        if prefix.isEmpty {
            matches = sortedAlphabetically[sortedAlphabetically.startIndex..<sortedAlphabetically.endIndex]
        } else {
            let lowerBound = sortedAlphabetically.partitioningIndex { element in
                element.0.compare(prefix, options: [.caseInsensitive]) != .orderedAscending
            }

            let upperBound = sortedAlphabetically[lowerBound...].partitioningIndex { element in
                element.0.range(of: prefix, options: [.anchored, .caseInsensitive]) == nil
            }

            matches = sortedAlphabetically[lowerBound..<upperBound]
        }

        matches = switch sort {
        case .alphabetical: matches
        case .length: ArraySlice(matches.sorted(using: KeyPathComparator(\.0.count)))
        }

        return matches
            .lazy
            .map { item in
                .init(
                    value: item.1,
                    string: item.0,
                    range: (0..<item.0.count).toStringIndices(in: item.0)!,
                )
            }
    }

    func matching(anywhere string: String, sortingBy sort: Sort = .alphabetical) -> any Sequence<Match<T>> {
        let matches = switch sort {
        case .alphabetical: sortedAlphabetically
        case .length: sortedByLength
        }

        return matches
            .lazy
            .compactMap { item in
                if let range = item.0.range(of: string, options: .caseInsensitive) {
                    (range, item)
                } else {
                    nil
                }
            }
            .map { (range, item) in
                .init(
                    value: item.1,
                    string: item.0,
                    range: range,
                )
            }
    }
}

extension IndexedEnumerationValues where T == String {
    init(_ values: [T]) {
        self.init(values, \.self)
    }
}
