import Vapor
import Fluent

struct AIController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let ai = routes.grouped("ai")
        
        // GET /ai/training-data -> Historical games for ML training
        ai.get("training-data") { req async throws -> [TrainingDataPoint] in
            let games = try await Game.query(on: req.db)
                .filter(\.$status, .equal, "completed")
                .all()
            
            return games.map { game in
                let outcome: GameOutcome
                if let vs = game.visitorScore, let hs = game.homeScore {
                    if vs > hs {
                        outcome = .visitorWin
                    } else if hs > vs {
                        outcome = .homeWin
                    } else {
                        outcome = .tie
                    }
                } else {
                    outcome = .homeWin
                }
                
                let goalDiff = abs((game.homeScore ?? 0) - (game.visitorScore ?? 0))
                let totalGoals = (game.homeScore ?? 0) + (game.visitorScore ?? 0)
                
                return TrainingDataPoint(
                    id: game.externalId ?? UUID().uuidString,
                    gameDate: game.gameDate,
                    visitorTeam: game.visitorTeam,
                    homeTeam: game.homeTeam,
                    visitorScore: game.visitorScore,
                    homeScore: game.homeScore,
                    location: game.location,
                    status: game.status,
                    dataSource: game.dataSource,
                    gameURL: game.gameURL,
                    outcome: outcome,
                    goalDifference: goalDiff,
                    totalGoals: totalGoals
                )
            }
        }
        
        // GET /ai/team-stats -> Aggregated team stats for model features
        ai.get("team-stats") { req async throws -> [TeamStatsAI] in
            let games = try await Game.query(on: req.db)
                .filter(\.$status, .equal, "completed")
                .all()
            
            var statsDict: [String: (gf: Int, ga: Int, w: Int, l: Int, t: Int, games: Int)] = [:]
            
            for game in games {
                guard let visitor = game.visitorTeam, let home = game.homeTeam,
                      let vs = game.visitorScore, let hs = game.homeScore else { continue }
                
                if statsDict[visitor] == nil {
                    statsDict[visitor] = (0, 0, 0, 0, 0, 0)
                }
                if statsDict[home] == nil {
                    statsDict[home] = (0, 0, 0, 0, 0, 0)
                }
                
                var vStats = statsDict[visitor]!
                vStats.gf += vs
                vStats.ga += hs
                vStats.games += 1
                if vs > hs { vStats.w += 1 }
                else if vs < hs { vStats.l += 1 }
                else { vStats.t += 1 }
                statsDict[visitor] = vStats
                
                var hStats = statsDict[home]!
                hStats.gf += hs
                hStats.ga += vs
                hStats.games += 1
                if hs > vs { hStats.w += 1 }
                else if hs < vs { hStats.l += 1 }
                else { hStats.t += 1 }
                statsDict[home] = hStats
            }
            
            return statsDict.map { team, stats in
                TeamStatsAI(
                    teamName: team,
                    totalGames: stats.games,
                    wins: stats.w,
                    losses: stats.l,
                    ties: stats.t,
                    goalsFor: stats.gf,
                    goalsAgainst: stats.ga,
                    averageGoalsFor: stats.games > 0 ? Double(stats.gf) / Double(stats.games) : 0,
                    averageGoalsAgainst: stats.games > 0 ? Double(stats.ga) / Double(stats.games) : 0,
                    winRate: stats.games > 0 ? Double(stats.w) / Double(stats.games) : 0,
                    lastUpdated: Date()
                )
            }
            .sorted { $0.teamName < $1.teamName }
        }
        
        // GET /ai/league-stats -> League-wide context for normalization
        ai.get("league-stats") { req async throws -> LeagueStatsAI in
            let games = try await Game.query(on: req.db)
                .filter(\.$status, .equal, "completed")
                .all()
            
            let sources = Set(games.map { $0.dataSource })
            let dataSourceStr = sources.joined(separator: ", ")
            
            var homeWins = 0
            var totalCompletedGames = 0
            var totalGoalsFor = 0
            var totalGoalsAgainst = 0
            var teamGoals: [String: Int] = [:]
            
            for game in games {
                totalCompletedGames += 1
                
                if let hs = game.homeScore, let vs = game.visitorScore {
                    totalGoalsFor += (hs + vs)
                    if hs > vs { homeWins += 1 }
                }
                
                if let team = game.homeTeam {
                    teamGoals[team, default: 0] += game.homeScore ?? 0
                }
                if let team = game.visitorTeam {
                    teamGoals[team, default: 0] += game.visitorScore ?? 0
                }
            }
            
            let topTeam = teamGoals.max(by: { $0.value < $1.value })?.key
            let bottomTeam = teamGoals.min(by: { $0.value < $1.value })?.key
            
            let fromDate = games.min(by: { $0.gameDate < $1.gameDate })?.gameDate ?? Date()
            let toDate = games.max(by: { $0.gameDate < $1.gameDate })?.gameDate ?? Date()
            
            let avgGoals = totalCompletedGames > 0 ? Double(totalGoalsFor) / Double(totalCompletedGames) : 0
            let homeWinRate = totalCompletedGames > 0 ? Double(homeWins) / Double(totalCompletedGames) : 0
            let totalTeams = Set(games.compactMap { $0.homeTeam }).count
            
            return LeagueStatsAI(
                dataSource: dataSourceStr,
                fromDate: fromDate,
                toDate: toDate,
                totalGames: totalCompletedGames,
                totalTeams: totalTeams,
                averageGoalsPerGame: avgGoals,
                averageGoalsAgainst: avgGoals,  // symmetric in aggregate
                homeTeamWinRate: homeWinRate,
                topScoringTeam: topTeam,
                lowestScoringTeam: bottomTeam
            )
        }
        
        // GET /ai/training-data/export?format=csv|json|jsonl -> Export training data
        ai.get("training-data", "export") { req async throws -> Response in
            let format = (try? req.query.get(String.self, at: "format")) ?? "json"
            guard ["csv", "json", "jsonl"].contains(format.lowercased()) else {
                throw Abort(.badRequest, reason: "Format must be csv, json, or jsonl")
            }
            
            let games = try await Game.query(on: req.db)
                .filter(\.$status, .equal, "completed")
                .all()
            
            let trainingData = games.map { game -> TrainingDataPoint in
                let outcome: GameOutcome
                if let vs = game.visitorScore, let hs = game.homeScore {
                    outcome = vs > hs ? .visitorWin : (hs > vs ? .homeWin : .tie)
                } else {
                    outcome = .homeWin
                }
                
                return TrainingDataPoint(
                    id: game.externalId ?? UUID().uuidString,
                    gameDate: game.gameDate,
                    visitorTeam: game.visitorTeam,
                    homeTeam: game.homeTeam,
                    visitorScore: game.visitorScore,
                    homeScore: game.homeScore,
                    location: game.location,
                    status: game.status,
                    dataSource: game.dataSource,
                    gameURL: game.gameURL,
                    outcome: outcome,
                    goalDifference: abs((game.homeScore ?? 0) - (game.visitorScore ?? 0)),
                    totalGoals: (game.homeScore ?? 0) + (game.visitorScore ?? 0)
                )
            }
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            let filename: String
            let contentData: Data
            
            switch format.lowercased() {
            case "csv":
                filename = "training_data_\(ISO8601DateFormatter().string(from: Date())).csv"
                let csv = trainingDataToCSV(trainingData)
                contentData = csv.data(using: .utf8) ?? Data()
                
            case "jsonl":
                filename = "training_data_\(ISO8601DateFormatter().string(from: Date())).jsonl"
                var jsonlLines: [String] = []
                for item in trainingData {
                    if let encoded = try? encoder.encode(item),
                       let line = String(data: encoded, encoding: .utf8) {
                        jsonlLines.append(line)
                    }
                }
                contentData = jsonlLines.joined(separator: "\n").data(using: .utf8) ?? Data()
                
            default:  // json
                filename = "training_data_\(ISO8601DateFormatter().string(from: Date())).json"
                contentData = try encoder.encode(trainingData)
            }
            
            var response = Response(status: .ok, body: Response.Body(data: contentData))
            response.headers.contentType = HTTPMediaType(type: "application", subType: "octet-stream")
            response.headers.replaceOrAdd(name: .contentDisposition, value: "attachment; filename=\"\(filename)\"")
            return response
        }
    }
    
    private func trainingDataToCSV(_ data: [TrainingDataPoint]) -> String {
        var csv = "id,gameDate,visitorTeam,homeTeam,visitorScore,homeScore,outcome,goalDifference,totalGoals,location,status,dataSource\n"
        
        let formatter = ISO8601DateFormatter()
        
        for item in data {
            let id = escapeCSV(item.id)
            let date = formatter.string(from: item.gameDate)
            let visitor = escapeCSV(item.visitorTeam ?? "")
            let home = escapeCSV(item.homeTeam ?? "")
            let vScore = String(item.visitorScore ?? 0)
            let hScore = String(item.homeScore ?? 0)
            let outcome = item.outcome.rawValue
            let goalDiff = String(item.goalDifference)
            let totalGoals = String(item.totalGoals)
            let loc = escapeCSV((item.location ?? "").replacingOccurrences(of: ",", with: ";"))
            let status = escapeCSV(item.status ?? "")
            let source = item.dataSource
            
            let row = "\"\(id)\",\"\(date)\",\"\(visitor)\",\"\(home)\",\"\(vScore)\",\"\(hScore)\",\"\(outcome)\",\"\(goalDiff)\",\"\(totalGoals)\",\"\(loc)\",\"\(status)\",\"\(source)\""
            csv += row + "\n"
        }
        
        return csv
    }
    
    private func escapeCSV(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "\"\"")
    }
}
