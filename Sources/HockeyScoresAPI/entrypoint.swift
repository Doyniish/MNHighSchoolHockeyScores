import Vapor
import Logging
import NIOCore
import NIOPosix
import Foundation

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

            app.get("scores") { req async throws -> [ScoreItem] in
                let scoresURL = URI(string: "https://www.legacy.hockey/schedule/day/league_instance/224377?subseason=948428")
                let response = try await req.client.get(scoresURL)
                guard response.status == .ok, var body = response.body else {
                    return []
                }
                let bytes = body.readBytes(length: body.readableBytes) ?? []
                let html = String(decoding: bytes, as: UTF8.self)
                return ScoresParser.parseScores(from: html)
            }

            // GET /scores/:year/:month/:day -> returns parsed scores for a specific date
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
                // zero-pad month/day for consistency if needed elsewhere
                let mm = String(format: "%02d", month)
                let dd = String(format: "%02d", day)
                req.logger.info("Fetching scores for date: \(year)-\(mm)-\(dd)")

                // The legacy.hockey daily view URL doesn't take date components directly; it uses the selected day slider.
                // If a direct date URL is available, replace this base with the date-specific endpoint. For now we reuse the same league/subseason page.
                let scoresURL = URI(string: "https://www.legacy.hockey/schedule/day/league_instance/224377?subseason=948428")
                let response = try await req.client.get(scoresURL)
                guard response.status == .ok, var body = response.body else {
                    return []
                }
                let bytes = body.readBytes(length: body.readableBytes) ?? []
                let html = String(decoding: bytes, as: UTF8.self)
                return ScoresParser.parseScores(from: html)
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
