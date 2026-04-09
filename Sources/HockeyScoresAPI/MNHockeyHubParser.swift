import Foundation
import Vapor

public enum MNHockeyHubParser {
    /// Helper to extract first regex match
    private static func firstMatch(in text: String, pattern: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex?.firstMatch(in: text, options: [], range: range),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    /// Helper to extract all regex matches
    private static func allMatches(in text: String, pattern: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex?.matches(in: text, options: [], range: range) ?? []
        return matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    /// Helper to extract numbers from regex matches
    private static func allNumberMatches(in text: String, pattern: String) -> [Int] {
        return allMatches(in: text, pattern: pattern).compactMap { Int($0) }
    }

    /// Parses HTML from MN Hockey Hub schedule page, returning score items
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
            let id = firstMatch(in: rowHTML, pattern: #"id=\"([^\"]+)\""#)
            guard id?.hasPrefix("game_list_row_") == true else { continue }

            // Extract class list to infer status
            let classAttr = firstMatch(in: rowHTML, pattern: #"class=\"([^\"]+)\""#)
            let status: String? = {
                guard let classes = classAttr else { return nil }
                if classes.contains("completed") { return "completed" }
                if classes.contains("in_progress") { return "in_progress" }
                if classes.contains("scheduled") { return "scheduled" }
                return nil
            }()

            // Extract team names (first two occurrences of <a class="teamName">...)</a>
            let teamPattern = #"<a[^>]*class=\"teamName\"[^>]*>([\s\S]*?)</a>"#
            let teamNames = allMatches(in: rowHTML, pattern: teamPattern)
            let visitorTeam = teamNames.first?.publicTrimmedHTMLText()
            let homeTeam = teamNames.dropFirst().first?.publicTrimmedHTMLText()

            // Extract scores from the next <td> cells with numbers; may contain <div class="winner">&nbsp;X&nbsp;</div>
            let scorePattern = #"<td>\s*<div[^>]*>\s*&nbsp;([0-9]+)&nbsp;\s*</div>\s*</td>"#
            let scoreValues = allNumberMatches(in: rowHTML, pattern: scorePattern)
            let visitorScore = scoreValues.first
            let homeScore = scoreValues.dropFirst().first

            // Extract location: a <div class="scheduleListTeam">...</div> inside the 5th <td>
            let locationPattern = #"<td>\s*<div[^>]*class=\"scheduleListTeam\"[^>]*>([\s\S]*?)</div>\s*</td>"#
            let allLocations = allMatches(in: rowHTML, pattern: locationPattern)
            // Typically the third occurrence corresponds to location cell
            let location = allLocations.dropFirst(2).first?.publicTrimmedHTMLText()

            // Extract status label within the last cell: either <img alt="..."> or <span>time</span>
            let statusLabel = firstMatch(in: rowHTML, pattern: #"<img[^>]*alt=\"([^\"]+)\""#)
                ?? firstMatch(in: rowHTML, pattern: #"<span>([\s\S]*?)</span>"#)?.publicTrimmedHTMLText()

            // Extract game URL if present
            let gameURL = firstMatch(in: rowHTML, pattern: #"<a[^>]*class=\"game_link_referrer\"[^>]*href=\"([^\"]+)\""#)

            let rawLine = rowHTML.publicStrippedTags().publicCollapsedWhitespace()

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
