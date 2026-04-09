import Vapor
import Logging
import NIOCore
import NIOPosix
import Foundation
import Fluent
import FluentSQL

@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        
        let app = try await Application.make(env)

        // This attempts to install NIO as the Swift Concurrency global executor.
        // You can enable it if you'd like to reduce the amount of context switching between NIO and Swift Concurrency.
        // Note: this has caused issues with some libraries that use `.wait()` and cleanly shutting down.
        // If enabled, you should be careful about calling async functions before this point as it can cause assertion failures.
        // let executorTakeoverSuccess = NIOSingletons.unsafeTryInstallSingletonPosixEventLoopGroupAsConcurrencyGlobalExecutor()
        // app.logger.debug("Tried to install SwiftNIO's EventLoopGroup as Swift's global concurrency executor", metadata: ["success": .stringConvertible(executorTakeoverSuccess)])
        
        do {
            try await configure(app)

            // Serve files from Public/
            app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

            // Helper function to fetch scores from a specific source
            @Sendable
            func fetchScoresFromSource(
                url: String,
                parser: (String) -> [ScoreItem],
                dataSource: String,
                for date: Date,
                on db: any Database
            ) async throws -> [ScoreItem] {
                let uri = URI(string: url)
                let response = try await app.client.get(uri)
                guard response.status == .ok, var body = response.body else {
                    return []
                }
                let bytes = body.readBytes(length: body.readableBytes) ?? []
                let html = String(decoding: bytes, as: UTF8.self)
                let items = parser(html)

                // Save fetched scores to database with data source tracking
                for item in items {
                    // Check if game already exists (to avoid duplicates from same source)
                    let existingGame = try await Game.query(on: db)
                        .filter(\.$externalId, .equal, item.id ?? "")
                        .filter(\.$gameDate, .greaterThanOrEqual, date)
                        .filter(\.$gameDate, .lessThan, Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date)
                        .filter(\.$dataSource, .equal, dataSource)
                        .first()
                    
                    guard existingGame == nil else { continue }  // Skip if already saved from this source
                    
                    let game = Game(
                        externalId: item.id,
                        dataSource: dataSource,
                        gameDate: date,
                        visitorTeam: item.visitorTeam,
                        visitorScore: item.visitorScore,
                        homeTeam: item.homeTeam,
                        homeScore: item.homeScore,
                        location: item.location,
                        status: item.status,
                        statusLabel: item.statusLabel,
                        gameURL: item.gameURL
                    )
                    try await game.save(on: db)
                }
                return items
            }

            // Fetch and aggregate scores from all sources
            @Sendable
            func fetchAndSaveScoresFromAllSources(for date: Date, on db: any Database) async throws -> [ScoreItem] {
                var allItems: [ScoreItem] = []
                let legacyHockeyURL = "https://www.legacy.hockey/schedule/day/league_instance/224377?subseason=948428"
                let mnHockeyHubURL = "https://stats.mnhockeyhub.com/schedule/day/league_instance/226701?subseason=954110"

                // Fetch from legacy.hockey
                do {
                    let legacyItems = try await fetchScoresFromSource(
                        url: legacyHockeyURL,
                        parser: ScoresParser.parseScores,
                        dataSource: "legacy_hockey",
                        for: date,
                        on: db
                    )
                    allItems.append(contentsOf: legacyItems)
                    app.logger.info("Fetched \(legacyItems.count) games from legacy.hockey")
                } catch {
                    app.logger.warning("Failed to fetch from legacy.hockey: \(error)")
                }

                // Fetch from MN Hockey Hub
                do {
                    let mnItems = try await fetchScoresFromSource(
                        url: mnHockeyHubURL,
                        parser: MNHockeyHubParser.parseScores,
                        dataSource: "mn_hockey_hub",
                        for: date,
                        on: db
                    )
                    allItems.append(contentsOf: mnItems)
                    app.logger.info("Fetched \(mnItems.count) games from MN Hockey Hub")
                } catch {
                    app.logger.warning("Failed to fetch from MN Hockey Hub: \(error)")
                }

                return allItems
            }

            app.get("scores") { req async throws -> [ScoreItem] in
                // Normalize today's date to midnight UTC
                let calendar = Calendar.current
                let today = Date()
                let components = calendar.dateComponents([.year, .month, .day], from: today)
                let normalizedToday = calendar.date(from: components) ?? today
                
                _ = try? await fetchAndSaveScoresFromAllSources(for: normalizedToday, on: req.db)
                let games = try await Game.query(on: req.db).all()
                return games.map { $0.toScoreItem() }
            }

            // GET /scores/:year/:month/:day -> returns scores for a specific date
            app.get("scores", ":year", ":month", ":day") { req async throws -> [ScoreItem] in
                guard let yearStr = req.parameters.get("year"),
                      let monthStr = req.parameters.get("month"),
                      let dayStr = req.parameters.get("day"),
                      let year = Int(yearStr),
                      let month = Int(monthStr),
                      let day = Int(dayStr),
                      (1...12).contains(month),
                      (1...31).contains(day)
                else {
                    throw Abort(.badRequest, reason: "Invalid date parameters")
                }

                // Create a date for midnight UTC on the requested date
                let calendar = Calendar(identifier: .gregorian)
                var components = DateComponents()
                components.year = year
                components.month = month
                components.day = day
                components.hour = 0
                components.minute = 0
                components.second = 0
                components.timeZone = TimeZone(abbreviation: "UTC")
                
                guard let targetDate = calendar.date(from: components) else {
                    throw Abort(.badRequest, reason: "Invalid date")
                }
                
                let nextDay = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate

                // Query database for games on this specific date using date range
                let games = try await Game.query(on: req.db)
                    .filter(\.$gameDate, .greaterThanOrEqual, targetDate)
                    .filter(\.$gameDate, .lessThan, nextDay)
                    .all()

                return games.map { $0.toScoreItem() }
            }

            // GET /scores/team/:name -> filter by a single team (case-insensitive contains)
            app.get("scores", "team", ":name") { req async throws -> [ScoreItem] in
                let nameParam = req.parameters.get("name")?.replacingOccurrences(of: "+", with: " ") ?? ""
                let needle = nameParam.lowercased()
                guard !needle.isEmpty else { return [] }

                let scoresURL = URI(string: "https://www.legacy.hockey/schedule/day/league_instance/224377?subseason=948428")
                let response = try await req.client.get(scoresURL)
                guard response.status == .ok, var body = response.body else { return [] }
                let bytes = body.readBytes(length: body.readableBytes) ?? []
                let html = String(decoding: bytes, as: UTF8.self)
                let items = ScoresParser.parseScores(from: html)
                return items.filter { item in
                    let v = item.visitorTeam?.lowercased() ?? ""
                    let h = item.homeTeam?.lowercased() ?? ""
                    return v.contains(needle) || h.contains(needle)
                }
            }

            // GET /scores/teams?names=a,b,c -> filter by multiple teams (comma-separated, case-insensitive contains)
            app.get("scores", "teams") { req async throws -> [ScoreItem] in
                let raw = (try? req.query.get(String.self, at: "names")) ?? ""
                let needles = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
                guard !needles.isEmpty else { return [] }

                let scoresURL = URI(string: "https://www.legacy.hockey/schedule/day/league_instance/224377?subseason=948428")
                let response = try await req.client.get(scoresURL)
                guard response.status == .ok, var body = response.body else { return [] }
                let bytes = body.readBytes(length: body.readableBytes) ?? []
                let html = String(decoding: bytes, as: UTF8.self)
                let items = ScoresParser.parseScores(from: html)
                return items.filter { item in
                    let v = item.visitorTeam?.lowercased() ?? ""
                    let h = item.homeTeam?.lowercased() ?? ""
                    return needles.contains(where: { v.contains($0) || h.contains($0) })
                }
            }

            // Fetch today's hockey scores from legacy.hockey before starting the server
            let scoresURL = URI(string: "https://www.legacy.hockey/schedule/day/league_instance/224377?subseason=948428")
            do {
                let response = try await app.client.get(scoresURL)
                if response.status == .ok, var body = response.body {
                    let bytes = body.readBytes(length: body.readableBytes) ?? []
                    let html = String(decoding: bytes, as: UTF8.self)

                    // Very lightweight parsing to try to extract game rows and scores.
                    // This avoids adding dependencies. Adjust selectors as needed if the site structure changes.
                    let items = ScoresParser.parseScores(from: html)
                    if items.isEmpty {
                        app.logger.info("Fetched schedule page (\(html.count) chars), but did not detect score lines. Consider adding a proper HTML parser if needed.")
                    } else {
                        for item in items { app.logger.info("Score: \(item.rawLine)") }
                    }
                } else {
                    app.logger.warning("Failed to fetch scores page: status=\(response.status.code)")
                }
            } catch {
                app.logger.error("Error fetching scores: \(error.localizedDescription)")
            }

            try await app.execute()
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }
}
