import Vapor
import Fluent

struct StatsController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let stats = routes.grouped("stats")
        
        // GET /stats/teams -> All team statistics
        stats.get("teams") { req async throws -> [TeamStats] in
            let games = try await Game.query(on: req.db).all()
            return calculateAllTeamStats(from: games)
        }
        
        // GET /stats/team/:name -> Specific team statistics
        stats.get("team", ":name") { req async throws -> TeamStats in
            guard let teamName = req.parameters.get("name")?.replacingOccurrences(of: "+", with: " ") else {
                throw Abort(.badRequest, reason: "Team name required")
            }
            
            let games = try await Game.query(on: req.db).all()
            let teamStats = calculateAllTeamStats(from: games)
            
            guard let stat = teamStats.first(where: { $0.teamName.lowercased() == teamName.lowercased() }) else {
                throw Abort(.notFound, reason: "Team '\(teamName)' not found")
            }
            return stat
        }
        
        // GET /stats/league -> League-wide statistics
        stats.get("league") { req async throws -> LeagueStats in
            let games = try await Game.query(on: req.db).all()
            let teamStats = calculateAllTeamStats(from: games)
            
            let totalGoals = games.compactMap { ($0.homeScore ?? 0) + ($0.visitorScore ?? 0) }.reduce(0, +)
            let gamesCount = games.filter { $0.status == "completed" }.count
            let avgGoals = gamesCount > 0 ? Double(totalGoals) / Double(gamesCount) : 0
            
            let goalDifferences = games.map { abs(($0.homeScore ?? 0) - ($0.visitorScore ?? 0)) }
            let avgGoDiff = goalDifferences.isEmpty ? 0 : Double(goalDifferences.reduce(0, +)) / Double(goalDifferences.count)
            
            let dateRange = DateRange(
                from: games.min(by: { $0.gameDate < $1.gameDate })?.gameDate ?? Date(),
                to: games.max(by: { $0.gameDate < $1.gameDate })?.gameDate ?? Date()
            )
            
            return LeagueStats(
                totalGamesPlayed: gamesCount,
                totalTeams: teamStats.count,
                dateRange: dateRange,
                topTeamsByWinPercentage: Array(teamStats.sorted { $0.winPercentage > $1.winPercentage }.prefix(10)),
                topTeamsByGoalDifference: Array(teamStats.sorted { $0.goalDifference > $1.goalDifference }.prefix(10)),
                averageGoalsPerGame: avgGoals,
                averageGoalsDifference: avgGoDiff
            )
        }
        
        // GET /stats/head-to-head/:team1/:team2 -> Head-to-head record
        stats.get("head-to-head", ":team1", ":team2") { req async throws -> HeadToHeadRecord in
            guard let t1 = req.parameters.get("team1"), let t2 = req.parameters.get("team2") else {
                throw Abort(.badRequest, reason: "Both team names required")
            }
            
            let team1 = t1.replacingOccurrences(of: "+", with: " ")
            let team2 = t2.replacingOccurrences(of: "+", with: " ")
            
            let games = try await Game.query(on: req.db)
                .filter(\.$status, .equal, "completed")
                .all()
                .filter { game in
                    let v = game.visitorTeam?.lowercased() ?? ""
                    let h = game.homeTeam?.lowercased() ?? ""
                    let t1Lower = team1.lowercased()
                    let t2Lower = team2.lowercased()
                    return (v.contains(t1Lower) && h.contains(t2Lower)) || (v.contains(t2Lower) && h.contains(t1Lower))
                }
                .sorted { $0.gameDate > $1.gameDate }
            
            var team1Wins = 0, team2Wins = 0, ties = 0
            var team1GoalsFor = 0, team2GoalsFor = 0
            
            for game in games {
                let visitorMatches = (game.visitorTeam?.lowercased() ?? "").contains(team1.lowercased())
                let homeMatches = (game.homeTeam?.lowercased() ?? "").contains(team1.lowercased())
                
                let team1Score = visitorMatches ? (game.visitorScore ?? 0) : (homeMatches ? (game.homeScore ?? 0) : 0)
                let team2Score = visitorMatches ? (game.homeScore ?? 0) : (homeMatches ? (game.visitorScore ?? 0) : 0)
                
                if team1Score > team2Score {
                    team1Wins += 1
                } else if team2Score > team1Score {
                    team2Wins += 1
                } else {
                    ties += 1
                }
                
                team1GoalsFor += team1Score
                team2GoalsFor += team2Score
            }
            
            return HeadToHeadRecord(
                team1: team1,
                team2: team2,
                team1Wins: team1Wins,
                team2Wins: team2Wins,
                ties: ties,
                team1GoalsFor: team1GoalsFor,
                team2GoalsFor: team2GoalsFor,
                recentGames: Array(games.prefix(10)).map { $0.toScoreItem() }
            )
        }
    }
    
    private func calculateAllTeamStats(from games: [Game]) -> [TeamStats] {
        var statsDict: [String: (played: Int, wins: Int, losses: Int, ties: Int, gf: Int, ga: Int)] = [:]
        
        for game in games where game.status == "completed" {
            guard let visitor = game.visitorTeam, let home = game.homeTeam,
                  let vs = game.visitorScore, let hs = game.homeScore else { continue }
            
            // Ensure team entries exist
            if statsDict[visitor] == nil {
                statsDict[visitor] = (0, 0, 0, 0, 0, 0)
            }
            if statsDict[home] == nil {
                statsDict[home] = (0, 0, 0, 0, 0, 0)
            }
            
            // Update visitor team
            var vStats = statsDict[visitor]!
            vStats.played += 1
            vStats.gf += vs
            vStats.ga += hs
            if vs > hs { vStats.wins += 1 }
            else if vs < hs { vStats.losses += 1 }
            else { vStats.ties += 1 }
            statsDict[visitor] = vStats
            
            // Update home team
            var hStats = statsDict[home]!
            hStats.played += 1
            hStats.gf += hs
            hStats.ga += vs
            if hs > vs { hStats.wins += 1 }
            else if hs < vs { hStats.losses += 1 }
            else { hStats.ties += 1 }
            statsDict[home] = hStats
        }
        
        return statsDict.map { team, stats in
            let winPct = stats.played > 0 ? Double(stats.wins) / Double(stats.played) * 100 : 0
            return TeamStats(
                teamName: team,
                played: stats.played,
                wins: stats.wins,
                losses: stats.losses,
                ties: stats.ties,
                goalsFor: stats.gf,
                goalsAgainst: stats.ga,
                goalDifference: stats.gf - stats.ga,
                winPercentage: winPct,
                averageGoalsFor: stats.played > 0 ? Double(stats.gf) / Double(stats.played) : 0,
                averageGoalsAgainst: stats.played > 0 ? Double(stats.ga) / Double(stats.played) : 0
            )
        }
        .sorted { $0.teamName < $1.teamName }
    }
}
