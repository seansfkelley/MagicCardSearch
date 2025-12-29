//
//  DatabaseMigrationTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-29.
//
import Testing
@testable import MagicCardSearch

struct DatabaseMigrationTests {
    @Test
    func testMigrationVersionsOrdered() throws {
        try #require(orderedMigrations.count >= 1)
        #expect(orderedMigrations.first!.version == 1)

        for i in 1..<orderedMigrations.count {
            let previous = orderedMigrations[i - 1]
            let current = orderedMigrations[i]
            #expect(current.version == previous.version + 1)
        }
    }

    @Test
    func testMigratesFromEmpty() async throws {
        let db = try SQLiteDatabase.initializeTest()
        #expect(db.userVersion! == orderedMigrations.last!.version)
    }
}
