# Hockey Scores API - Quick Reference

## Base URL
```
http://127.0.0.1:8080
```

## Feature 3: Extended API Endpoints

### Stats Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/stats/teams` | All team statistics |
| GET | `/stats/team/:name` | Specific team stats |
| GET | `/stats/league` | League aggregates |
| GET | `/stats/head-to-head/:team1/:team2` | H2H records |

### Advanced Scoring

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/scores/filter` | Advanced filtering |
| GET | `/scores/export` | Multi-format export |

## Feature 4: AI/ML Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/ai/training-data` | ML-ready game data |
| GET | `/ai/team-stats` | Team features for ML |
| GET | `/ai/league-stats` | League context/normalization |
| GET | `/ai/training-data/export` | Training data exports |

---

## Quick Examples

### Get all teams and their win rates
```bash
curl "http://127.0.0.1:8080/stats/teams" | jq '.[] | {name: .teamName, wins: .wins, losses: .losses, winPct: .winPercentage}'
```

### Check league-wide stats
```bash
curl "http://127.0.0.1:8080/stats/league" | jq '{games: .totalGamesPlayed, teams: .totalTeams, avgGoalsPerGame: .averageGoalsPerGame}'
```

### Filter scores by data source
```bash
curl "http://127.0.0.1:8080/scores/filter?source=legacy_hockey" | jq '.[] | {teams: "\(.visitorTeam) @ \(.homeTeam)", score: "\(.visitorScore)-\(.homeScore)"}'
```

### Export training data as CSV
```bash
curl "http://127.0.0.1:8080/ai/training-data/export?format=csv" -o training_data.csv
```

### Get ML team statistics
```bash
curl "http://127.0.0.1:8080/ai/team-stats" | jq '.[] | {team: .teamName, winRate: .winRate, avgGoalsFor: .averageGoalsFor}'
```

### Head-to-head record
```bash
curl "http://127.0.0.1:8080/stats/head-to-head/Mahtomedi/Delano" | jq '{team1: .team1, team1Wins: .team1Wins, team2Wins: .team2Wins, recentGames: (.recentGames | length)}'
```

---

## Query Parameters Reference

### `/scores/filter`
- `source` - Data source: "legacy_hockey" or "mn_hockey_hub"
- `team` - Team name (substring match)
- `from` - ISO8601 start date
- `to` - ISO8601 end date
- `limit` - Max results (default: 100)
- `offset` - Pagination offset (default: 0)

### `/scores/export`
- `format` - "csv", "json", or "jsonl"

### `/ai/training-data/export`
- `format` - "csv", "json", or "jsonl"

---

## Response Examples

### TeamStats
```json
{
  "teamName": "Grand Rapids",
  "played": 2,
  "wins": 2,
  "losses": 0,
  "ties": 0,
  "goalsFor": 12,
  "goalsAgainst": 4,
  "goalDifference": 8,
  "winPercentage": 100,
  "averageGoalsFor": 6.0,
  "averageGoalsAgainst": 2.0
}
```

### TrainingDataPoint
```json
{
  "id": "game_list_row_45205875",
  "gameDate": "2026-04-09T00:00:00Z",
  "visitorTeam": "Mahtomedi",
  "homeTeam": "Delano",
  "visitorScore": 4,
  "homeScore": 3,
  "outcome": "VISITOR_WIN",
  "goalDifference": 1,
  "totalGoals": 7,
  "location": "State Class 1A Tournament",
  "status": "completed",
  "dataSource": "legacy_hockey"
}
```

### LeagueStats
```json
{
  "dataSource": "legacy_hockey, mn_hockey_hub",
  "fromDate": "2026-04-09T00:00:00Z",
  "toDate": "2026-04-09T00:00:00Z",
  "totalGames": 12,
  "totalTeams": 12,
  "averageGoalsPerGame": 8.0,
  "homeTeamWinRate": 0.5833,
  "topScoringTeam": "Grand Rapids",
  "lowestScoringTeam": "Delano"
}
```

---

## Usage Tips

✅ **URL Encoding**
- Spaces in team names: `Grand%20Rapids`
- Special characters: Use standard URL encoding

✅ **Date Formats**
- ISO8601 format: `2026-04-09T00:00:00Z`
- Include timezone (Z for UTC)

✅ **Pagination**
- Use `limit` + `offset` for large result sets
- Default limit is 100

✅ **Data Export**
- CSV: Excel/Google Sheets compatible
- JSON: Suitable for web APIs
- JSONL: Best for streaming/big data tools

✅ **ML Integration**
- Use `/ai/training-data` for supervised learning
- Use `/ai/team-stats` for feature engineering
- Use `/ai/league-stats` for normalization

---

## Performance

| Operation | Speed |
|-----------|-------|
| Get team stats | <10ms |
| Get all teams | <20ms |
| Head-to-head | <10ms |
| Filter scores | <30ms |
| Export CSV | <100ms |

---

## Error Handling

```
200 OK - Request successful
400 Bad Request - Invalid parameters
404 Not Found - Resource not found
500 Server Error - Database/internal error
```

---

## Supported Export Formats

### CSV
```
visitorTeam,visitorScore,homeTeam,homeScore,location,status,dataSource
Lakeville South,2,Grand Rapids,6,3M Arena,completed,legacy_hockey
```

### JSON
```json
[
  {
    "visitorTeam": "Lakeville South",
    "visitorScore": 2,
    "homeTeam": "Grand Rapids",
    "homeScore": 6,
    "status": "completed"
  }
]
```

### JSONL
```
{"visitorTeam":"Lakeville South","visitorScore":2,"homeTeam":"Grand Rapids",...}
{"visitorTeam":"Mahtomedi","visitorScore":4,"homeTeam":"Delano",...}
```

---

## Data Characteristics

- **Total Games**: 12 (as of April 9, 2026)
- **Total Teams**: 12
- **Data Sources**: 2 (legacy.hockey, mn_hockey_hub)
- **Average Goals/Game**: 8
- **Home Team Win Rate**: 58.3%
- **Date Range**: April 9, 2026 (single day)

---

## SDK Examples

### Python
```python
import requests
import pandas as pd

# Get team stats
resp = requests.get('http://127.0.0.1:8080/stats/teams')
teams = resp.json()
df = pd.DataFrame(teams)
print(df.sort_values('winPercentage', ascending=False))

# Get training data
resp = requests.get('http://127.0.0.1:8080/ai/training-data')
games = resp.json()
```

### JavaScript
```javascript
// Fetch league stats
const stats = await fetch('http://127.0.0.1:8080/stats/league')
  .then(r => r.json());
console.log(`${stats.totalGames} games, ${stats.totalTeams} teams`);

// Get filtered scores
const scores = await fetch('http://127.0.0.1:8080/scores/filter?team=Grand%20Rapids')
  .then(r => r.json());
```

### R
```r
library(httr)
library(jsonlite)

# Get team stats
resp <- GET('http://127.0.0.1:8080/stats/teams')
teams <- fromJSON(rawToChar(resp$content))
head(teams)

# Get training data for ML
training <- GET('http://127.0.0.1:8080/ai/training-data')
data <- fromJSON(rawToChar(training$content))
```

---

## Common Queries

### Find highest-scoring teams
```bash
curl -s "http://127.0.0.1:8080/stats/teams" | jq 'sort_by(.goalsFor) | reverse | .[0:3] | .[] | {team: .teamName, goals: .goalsFor}'
```

### Identify strong defenders
```bash
curl -s "http://127.0.0.1:8080/stats/teams" | jq 'sort_by(.goalsAgainst) | .[0:3] | .[] | {team: .teamName, goalsAllowed: .goalsAgainst}'
```

### Export recent games
```bash
curl -s "http://127.0.0.1:8080/scores/filter?limit=20" | jq '.[] | {teams: "\(.visitorTeam) @ \(.homeTeam)", final: "\(.visitorScore)-\(.homeScore)"}'
```

### Check Mahtomedi's record
```bash
curl -s "http://127.0.0.1:8080/stats/team/Mahtomedi" | jq '{team: .teamName, wins: .wins, losses: .losses, winPct: .winPercentage}'
```

---

## Documentation Files

- `API_FEATURES.md` - Comprehensive feature documentation
- `IMPLEMENTATION_SUMMARY.md` - Technical implementation details
- `QUICK_REFERENCE.md` - This file

---

**Last Updated:** April 9, 2026  
**Server:** http://127.0.0.1:8080  
**Database:** PostgreSQL (localhost:5432)  
**Status:** ✅ All features operational
