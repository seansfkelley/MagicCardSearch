import GRDB

let orderedMigrations: [(String, @Sendable (Database) throws -> Void)] = [
    ("add bookmarks", migrate_001_AddBookmarks),
    ("add filter history", migrate_002_AddFilterHistory),
    ("add search history", migrate_003_AddSearchHistory),
    ("add pinned filters", migrate_004_AddPinnedFilters),
    ("add blob store", migrate_005_AddBlobStore),
    ("add pinned searches", migrate_006_AddPinnedSearches),
    ("truncate filter-related tables", migrate_007_TruncateFilterRelatedTables),
]
