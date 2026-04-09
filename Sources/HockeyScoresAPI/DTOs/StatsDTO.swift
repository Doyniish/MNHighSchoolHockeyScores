import Vapor

// Team statistics for a given season/period
struct TeamStats: Content, Codable {
    let teamName: String
    let played: Int
    let wins: Int
    let losses: Int
    let ties: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let goalDifference: Int
    let winPercentage: Double
    let averageGoalsFor: Double
    let averageGoalsAgainst: Double
    
    var description: String {
        "\(teamName): \(wins)W-\(losses)L-\(ties)T (\(String(format: "%.1f", winPercentage))%)"
    }
}

// Head-to-head record between two teams
struct HeadToHeadRecord: Content, Codable {
    let team1: String
    let team2: String
    let team1Wins: Int
    let team2Wins: Int
    let ties: Int
    let team1GoalsFor: Int
    let team2GoalsFor: Int
    let recentGames: [ScoreItem]
}

// League-wide statistics
struct LeagueStats: Content, Codable {
    let totalGamesPlayed: Int
    let totalTeams: Int
    let dateRange: DateRange
    let topTeamsByWinPercentage: [TeamStats]
    let topTeamsByGoalDifference: [TeamStats]
    let averageGoalsPerGame: Double
    let averageGoalsDifference: Double
}

struct DateRange: Content, Codable {
    let from: Date
    let to: Date
}

// Filter parameters
struct ScoresFilterParams: Content {
    let source: String?
    let team: String?
    let from: String?
    let to: String?
    let limit: Int?
    let offset: Int?
    
    var fromDate: Date? {
        guard let from else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: from)
    }
    
    var toDate: Date? {
        guard let to else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: to)
    }
}
