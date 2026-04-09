import Fluent
import Vapor

func routes(_ app: Application) throws {    
    // Serve index.html at "/"
    app.get { req async throws -> Response in
        // Resolve public directory: prefer PUBLIC_DIR env var, else use Vapor's configured directory
        let envPublic = Environment.get("PUBLIC_DIR")
        let basePublic = (envPublic?.isEmpty == false) ? (envPublic!.hasSuffix("/") ? envPublic! : envPublic! + "/") : app.directory.publicDirectory
        let filePath = basePublic + "index.html"
        guard FileManager.default.fileExists(atPath: filePath) else {
            req.logger.error("index.html not found", metadata: ["path": .string(filePath)])
            throw Abort(.notFound, reason: "index.html not found at \(filePath)")
        }
        let res = try await req.fileio.asyncStreamFile(at: filePath)
        res.headers.replaceOrAdd(name: .contentType, value: "text/html; charset=utf-8")
        return res
    }

    app.get("hello") { req async -> String in
        "Hello, world!"
    }

    // Register controllers
    try app.register(collection: TodoController())
    try app.register(collection: StatsController())
    try app.register(collection: AIController())
    
    // Extended scores filtering endpoints
    app.get("scores", "filter") { req async throws -> [ScoreItem] in
        // Query parameters:
        // - source: "legacy_hockey" or "mn_hockey_hub"
        // - team: team name substring
        // - from: ISO8601 date string
        // - to: ISO8601 date string
        // - limit: max results
        // - offset: pagination offset
        
        var query = Game.query(on: req.db)
        
        // Filter by source if provided
        if let source = try? req.query.get(String.self, at: "source"), !source.isEmpty {
            query = query.filter(\.$dataSource, .equal, source)
        }
        
        // Filter by date range if provided
        let formatter = ISO8601DateFormatter()
        if let fromStr = try? req.query.get(String.self, at: "from"), !fromStr.isEmpty, let fromDate = formatter.date(from: fromStr) {
            query = query.filter(\.$gameDate, .greaterThanOrEqual, fromDate)
        }
        if let toStr = try? req.query.get(String.self, at: "to"), !toStr.isEmpty, let toDate = formatter.date(from: toStr) {
            // Add 1 day to include entire "to" day
            let endDate = Calendar.current.date(byAdding: .day, value: 1, to: toDate) ?? toDate
            query = query.filter(\.$gameDate, .lessThan, endDate)
        }
        
        // Filter by status
        query = query.filter(\.$status, .equal, "completed")
        
        let offset = (try? req.query.get(Int.self, at: "offset")) ?? 0
        let limit = (try? req.query.get(Int.self, at: "limit")) ?? 100
        
        let games = try await query
            .offset(offset)
            .limit(limit)
            .all()
        
        // Filter by team name if provided (client-side filtering since Fluent doesn't support OR easily)
        var filtered = games
        if let teamName = try? req.query.get(String.self, at: "team"), !teamName.isEmpty {
            let needle = teamName.lowercased()
            filtered = games.filter { game in
                let v = game.visitorTeam?.lowercased() ?? ""
                let h = game.homeTeam?.lowercased() ?? ""
                return v.contains(needle) || h.contains(needle)
            }
        }
        
        return filtered.map { $0.toScoreItem() }
    }
    
    // Export scores in various formats
    app.get("scores", "export") { req async throws -> Response in
        let format = (try? req.query.get(String.self, at: "format")) ?? "json"
        guard ["csv", "json", "jsonl"].contains(format.lowercased()) else {
            throw Abort(.badRequest, reason: "Format must be csv, json, or jsonl")
        }
        
        let games = try await Game.query(on: req.db)
            .filter(\.$status, .equal, "completed")
            .all()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let filename: String
        let contentData: Data
        
        switch format.lowercased() {
        case "csv":
            filename = "scores_\(ISO8601DateFormatter().string(from: Date())).csv"
            let csv = gamesToCSV(games)
            contentData = csv.data(using: .utf8) ?? Data()
            
        case "jsonl":
            filename = "scores_\(ISO8601DateFormatter().string(from: Date())).jsonl"
            var jsonlLines: [String] = []
            for game in games {
                let scoreItem = game.toScoreItem()
                if let encoded = try? encoder.encode(scoreItem),
                   let line = String(data: encoded, encoding: .utf8) {
                    jsonlLines.append(line)
                }
            }
            contentData = jsonlLines.joined(separator: "\n").data(using: .utf8) ?? Data()
            
        default:  // json
            filename = "scores_\(ISO8601DateFormatter().string(from: Date())).json"
            let scoreItems = games.map { $0.toScoreItem() }
            contentData = try encoder.encode(scoreItems)
        }
        
        var response = Response(status: .ok, body: Response.Body(data: contentData))
        response.headers.contentType = HTTPMediaType(type: "application", subType: "octet-stream")
        response.headers.replaceOrAdd(name: .contentDisposition, value: "attachment; filename=\"\(filename)\"")
        return response
    }
}

private func gamesToCSV(_ games: [Game]) -> String {
    var csv = "visitorTeam,visitorScore,homeTeam,homeScore,location,status,statusLabel,gameDate,dataSource\n"
    
    let formatter = ISO8601DateFormatter()
    
    for game in games {
        let visitor = escapeCSV(game.visitorTeam ?? "")
        let vScore = String(game.visitorScore ?? 0)
        let home = escapeCSV(game.homeTeam ?? "")
        let hScore = String(game.homeScore ?? 0)
        let loc = escapeCSV((game.location ?? "").replacingOccurrences(of: ",", with: ";"))
        let status = escapeCSV(game.status ?? "")
        let statusLabel = escapeCSV(game.statusLabel ?? "")
        let date = formatter.string(from: game.gameDate)
        let source = game.dataSource
        
        let row = "\"\(visitor)\",\"\(vScore)\",\"\(home)\",\"\(hScore)\",\"\(loc)\",\"\(status)\",\"\(statusLabel)\",\"\(date)\",\"\(source)\""
        csv += row + "\n"
    }
    
    return csv
}

private func escapeCSV(_ value: String) -> String {
    value.replacingOccurrences(of: "\"", with: "\"\"")
}
