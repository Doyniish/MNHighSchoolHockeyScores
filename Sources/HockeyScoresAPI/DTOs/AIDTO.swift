import Vapor

// Training data for ML models - one game per record
struct TrainingDataPoint: Content, Codable {
    let id: String
    let gameDate: Date
    let visitorTeam: String?
    let homeTeam: String?
    let visitorScore: Int?
    let homeScore: Int?
    let location: String?
    let status: String?
    let dataSource: String
    let gameURL: String?
    let outcome: GameOutcome  // HOME_WIN, VISITOR_WIN, TIE
    let goalDifference: Int
    let totalGoals: Int
}

enum GameOutcome: String, Content, Codable {
    case homeWin = "HOME_WIN"
    case visitorWin = "VISITOR_WIN"
    case tie = "TIE"
}

// Aggregated team statistics for ML features
struct TeamStatsAI: Content, Codable {
    let teamName: String
    let totalGames: Int
    let wins: Int
    let losses: Int
    let ties: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let averageGoalsFor: Double
    let averageGoalsAgainst: Double
    let winRate: Double
    let lastUpdated: Date
}

// Player-level aggregated stats (if available)
struct PlayerStatsAggregate: Content, Codable {
    let playerName: String?
    let teamName: String
    let goals: Int
    let appearances: Int
    let averageGoalsPerGame: Double
}

// Temporal trends for time-series analysis
struct TrendDataPoint: Content, Codable {
    let date: Date
    let teamName: String
    let gamesPlayed: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let rollingSeason: String  // e.g., "2024-2025"
}

// League-wide aggregated statistics for context
struct LeagueStatsAI: Content, Codable {
    let dataSource: String
    let fromDate: Date
    let toDate: Date
    let totalGames: Int
    let totalTeams: Int
    let averageGoalsPerGame: Double
    let averageGoalsAgainst: Double
    let homeTeamWinRate: Double
    let topScoringTeam: String?
    let lowestScoringTeam: String?
}

// Export format options
struct ExportRequest: Content {
    let format: String  // "json", "csv", "jsonl"
    let includeStats: Bool?
    let dataSource: String?
}
