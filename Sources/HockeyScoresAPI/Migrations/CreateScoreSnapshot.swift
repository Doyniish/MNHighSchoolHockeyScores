import Fluent
import Vapor

struct CreateScoreSnapshot: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("score_snapshots")
            .id()
            .field("snapshot_date", .date, .required)
            .field("raw_html", .string, .required)
            .field("createdAt", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("score_snapshots").delete()
    }
}
