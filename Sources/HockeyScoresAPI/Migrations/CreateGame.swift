import Fluent

struct CreateGame: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("games")
            .id()
            .field("externalId", .string)
            .field("gameDate", .date, .required)
            .field("visitorTeam", .string)
            .field("visitorScore", .int)
            .field("homeTeam", .string)
            .field("homeScore", .int)
            .field("location", .string)
            .field("status", .string)
            .field("statusLabel", .string)
            .field("gameURL", .string)
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .unique(on: "externalId", "gameDate")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("games").delete()
    }
}
