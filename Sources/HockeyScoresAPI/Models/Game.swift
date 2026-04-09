import Fluent
import Vapor

final class Game: Model, Content, @unchecked Sendable {
    static let schema = "games"

    @ID(key: .id) var id: UUID?
    @Field(key: "externalId") var externalId: String?
    @Field(key: "gameDate") var gameDate: Date  // The date of the game
    @Field(key: "visitorTeam") var visitorTeam: String?
    @Field(key: "visitorScore") var visitorScore: Int?
    @Field(key: "homeTeam") var homeTeam: String?
    @Field(key: "homeScore") var homeScore: Int?
    @Field(key: "location") var location: String?
    @Field(key: "status") var status: String?  // completed, in_progress, scheduled
    @Field(key: "statusLabel") var statusLabel: String?
    @Field(key: "gameURL") var gameURL: String?
    @Timestamp(key: "createdAt", on: .create) var createdAt: Date?
    @Timestamp(key: "updatedAt", on: .update) var updatedAt: Date?

    init() { }

    init(
        externalId: String? = nil,
        gameDate: Date,
        visitorTeam: String? = nil,
        visitorScore: Int? = nil,
        homeTeam: String? = nil,
        homeScore: Int? = nil,
        location: String? = nil,
        status: String? = nil,
        statusLabel: String? = nil,
        gameURL: String? = nil
    ) {
        self.externalId = externalId
        self.gameDate = gameDate
        self.visitorTeam = visitorTeam
        self.visitorScore = visitorScore
        self.homeTeam = homeTeam
        self.homeScore = homeScore
        self.location = location
        self.status = status
        self.statusLabel = statusLabel
        self.gameURL = gameURL
    }
}

/// Convert Game model to ScoreItem for API responses
extension Game {
    func toScoreItem() -> ScoreItem {
        ScoreItem(
            id: externalId,
            visitorTeam: visitorTeam,
            visitorScore: visitorScore,
            homeTeam: homeTeam,
            homeScore: homeScore,
            location: location,
            status: status,
            statusLabel: statusLabel,
            gameURL: gameURL,
            rawLine: "\(visitorTeam ?? "") \(visitorScore ?? 0) - \(homeScore ?? 0) \(homeTeam ?? "")"
        )
    }
}
