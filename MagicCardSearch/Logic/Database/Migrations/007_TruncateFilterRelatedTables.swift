import GRDB

func migrate_007_TruncateFilterRelatedTables(db: Database) throws {
    try db.execute(sql: "DELETE FROM filterHistoryEntries")
    try db.execute(sql: "DELETE FROM searchHistoryEntries")
    try db.execute(sql: "DELETE FROM pinnedFilterEntries")
    try db.execute(sql: "DELETE FROM pinnedSearchEntries")
}
