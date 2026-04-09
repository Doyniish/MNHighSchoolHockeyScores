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

    try app.register(collection: TodoController())
}
