import Foundation
import Vapor

public struct ScoreItem: Content, Codable, Equatable {
    public let id: String?
    public let visitorTeam: String?
    public let visitorScore: Int?
    public let homeTeam: String?
    public let homeScore: Int?
    public let location: String?
    public let status: String?        // completed | in_progress | scheduled
    public let statusLabel: String?   // e.g., FINAL, In Progress, or time
    public let gameURL: String?
    public let rawLine: String        // original trimmed row text for debugging
}

public enum ScoresParser {
    // Parses an HTML document, returning lines that look like scores (e.g., "3 - 2").
    public static func parseScores(from html: String) -> [ScoreItem] {
        // Split into table rows
        let rowPattern = #"<tr[^>]*>([\s\S]*?)</tr>"#
        let trRegex = try? NSRegularExpression(pattern: rowPattern, options: [])
        let nsHTML = html as NSString
        let matches = trRegex?.matches(in: html, options: [], range: NSRange(location: 0, length: nsHTML.length)) ?? []

        var items: [ScoreItem] = []

        for match in matches {
            let rowHTML = nsHTML.substring(with: match.range(at: 0))
            // Only consider rows with game_list_row_... id to avoid header/footer
            let id = self.firstMatch(in: rowHTML, pattern: #"id=\"([^\"]+)\""#)
            guard id?.hasPrefix("game_list_row_") == true else { continue }

            // Extract class list to infer status
            let classAttr = self.firstMatch(in: rowHTML, pattern: #"class=\"([^\"]+)\""#)
            let status: String? = {
                guard let classes = classAttr else { return nil }
                if classes.contains("completed") { return "completed" }
                if classes.contains("in_progress") { return "in_progress" }
                if classes.contains("scheduled") { return "scheduled" }
                return nil
            }()

            // Extract team names (first two occurrences of <a class="teamName">...)</a>
            let teamPattern = #"<a[^>]*class=\"teamName\"[^>]*>([\s\S]*?)</a>"#
            let teamNames = self.allMatches(in: rowHTML, pattern: teamPattern)
            let visitorTeam = teamNames.first?.trimmedHTMLText()
            let homeTeam = teamNames.dropFirst().first?.trimmedHTMLText()

            // Extract scores from the next <td> cells with numbers; may contain <div class="winner">&nbsp;X&nbsp;</div>
            let scorePattern = #"<td>\s*<div[^>]*>\s*&nbsp;([0-9]+)&nbsp;\s*</div>\s*</td>"#
            let scoreValues = self.allNumberMatches(in: rowHTML, pattern: scorePattern)
            let visitorScore = scoreValues.first
            let homeScore = scoreValues.dropFirst().first

            // Extract location: a <div class="scheduleListTeam">...</div> inside the 5th <td>
            let locationPattern = #"<td>\s*<div[^>]*class=\"scheduleListTeam\"[^>]*>([\s\S]*?)</div>\s*</td>"#
            let allLocations = self.allMatches(in: rowHTML, pattern: locationPattern)
            // Typically the third occurrence corresponds to location cell
            let location = allLocations.dropFirst(2).first?.trimmedHTMLText()

            // Extract status label within the last cell: either <img alt="..."> or <span>time</span>
            let statusLabel = self.firstMatch(in: rowHTML, pattern: #"<img[^>]*alt=\"([^\"]+)\""#)
                ?? self.firstMatch(in: rowHTML, pattern: #"<span>([\s\S]*?)</span>"#)?.trimmedHTMLText()

            // Extract game URL if present
            let gameURL = self.firstMatch(in: rowHTML, pattern: #"<a[^>]*class=\"game_link_referrer\"[^>]*href=\"([^\"]+)\""#)

            let rawLine = rowHTML.strippedTags().collapsedWhitespace()

            items.append(ScoreItem(
                id: id,
                visitorTeam: visitorTeam,
                visitorScore: visitorScore,
                homeTeam: homeTeam,
                homeScore: homeScore,
                location: location,
                status: status,
                statusLabel: statusLabel,
                gameURL: gameURL,
                rawLine: rawLine
            ))
        }

        return items
    }
}

private extension String {
    func strippedTags() -> String {
        return self.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
    func collapsedWhitespace() -> String {
        return self.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    func trimmedHTMLText() -> String { self.strippedTags().collapsedWhitespace() }
}
private extension ScoresParser {
    static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)) else { return nil }
        guard m.numberOfRanges > 1 else { return nil }
        return ns.substring(with: m.range(at: 1))
    }
    static func allMatches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let ns = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        return matches.compactMap { m in
            guard m.numberOfRanges > 1 else { return nil }
            return ns.substring(with: m.range(at: 1))
        }
    }
    static func allNumberMatches(in text: String, pattern: String) -> [Int] {
        return allMatches(in: text, pattern: pattern).compactMap { Int($0) }
    }
}

