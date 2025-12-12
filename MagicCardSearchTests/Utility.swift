//
//  Utility.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-12.
//
func indexRange(_ from: Int, _ to: Int) -> Range<String.Index> {
    return
        String.Index.init(encodedOffset: from)
        ..<
        String.Index.init(encodedOffset: to)
}
