import GRDB

func migrate_008_AddRecentlyViewedCards(db: Database) throws {
    try db.create(table: "recentlyViewedCards") { t in
        t.column("id", .text).notNull().primaryKey(onConflict: .replace)
        t.column("viewedAt", .datetime).notNull()
        t.column("frontCardFace", .jsonText).notNull()
        t.column("backCardFace", .jsonText)
    }
}
