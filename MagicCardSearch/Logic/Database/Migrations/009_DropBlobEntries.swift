import GRDB

func migrate_009_DropBlobEntries(db: Database) throws {
    try db.drop(table: "blobEntries")
}
