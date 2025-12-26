//
//  Range+offset.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-15.
//
extension Range where Bound == String.Index {
    func shift(with string: String, by offset: Int) -> Range<String.Index> {
        let newLowerBound = string.index(lowerBound, offsetBy: offset)
        let newUpperBound = string.index(upperBound, offsetBy: offset)
        return newLowerBound..<newUpperBound
    }

    func inset(with string: String, left: Int = 0, right: Int = 0) -> Range<String.Index> {
        let newLowerBound = string.index(lowerBound, offsetBy: left)
        let newUpperBound = string.index(upperBound, offsetBy: -right)
        return newLowerBound..<newUpperBound
    }

    func length(in string: String) -> Int {
        string.distance(from: lowerBound, to: upperBound)
    }
}
