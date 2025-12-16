//
//  Range+offset.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-15.
//
extension Range where Bound == String.Index {
    func offset(with string: String, by offset: Int) -> Range<String.Index> {
        let newLowerBound = string.index(lowerBound, offsetBy: offset)
        let newUpperBound = string.index(upperBound, offsetBy: offset)
        return newLowerBound..<newUpperBound
    }
}
