//
//  SerializationTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-29.
//
import Testing
@testable import MagicCardSearch

struct SerializationTests {
    @Test
    func testBasicSerialization() throws {
        let db = try SQLiteDatabase.initialize(.memory)

        try db.filterHistory.recordUsage(of: .basic(false, "color", .including, "black"))
        let rows = try db.filterHistory.test_getAll()

        try #require(rows.count == 1)
        #expect(rows.first!.filter == .basic(false, "color", .including, "black"))
    }
}
