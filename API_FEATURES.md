# Extended API & AI Features

## Overview
The Hockey Scores API now includes two major feature sets:
1. **Extended API (Feature 3)** - Advanced filtering, stats aggregation, and data export
2. **AI-Ready Endpoints (Feature 4)** - Machine learning-friendly data formats and analytics

---

## Feature 3: Extended API

### 1. Advanced Scores Filtering (`GET /scores/filter`)

Query scores with flexible filtering options:

```bash
curl "http://127.0.0.1:8080/scores/filter?source=legacy_hockey&limit=10"
curl "http://127.0.0.1:8080/scores/filter?team=Grand%20Rapids&offset=0&limit=5"
curl "http://127.0.0.1:8080/scores/filter?from=2026-04-01T00:00:00Z&to=2026-04-09T23:59:59Z"
```

**Query Parameters:**
- `source` - Filter by data source: "legacy_hockey" or "mn_hockey_hub"
- `team` - Filter by team name (substring match, case-insensitive)
- `from` - Start date (ISO8601 format)
- `to` - End date (ISO8601 format)
- `limit` - Maximum results (default: 100)
- `offset` - Pagination offset (default: 0)

**Response:** Array of game objects with all details

---

### 2. Data Export Endpoints

#### Export Scores (`GET /scores/export`)

Export all games in multiple formats:

```bash
# CSV format
curl "http://127.0.0.1:8080/scores/export?format=csv" -o scores.csv

# JSON format
curl "http://127.0.0.1:8080/scores/export?format=json" -o scores.json

# JSONL format (one game per line)
curl "http://127.0.0.1:8080/scores/export?format=jsonl" -o scores.jsonl
```

**Parameters:** `format` - "csv", "json", or "jsonl"

**CSV Columns:** visitorTeam, visitorScore, homeTeam, homeScore, location, status, statusLabel, gameDate, dataSource

---

### 3. Team Statistics Endpoints

#### Get All Team Stats (`GET /stats/teams`)

```bash
curl "http://127.0.0.1:8080/stats/teams" | jq '.'
```

**Response Fields per Team:**
- `teamName` - Team name
- `played` - Total games played
- `wins`, `losses`, `ties` - Record
- `goalsFor` / `goalsAgainst` - Total goals
- `goalDifference` - Net goal differential
- `winPercentage` - Win rate (0-100)
- `averageGoalsFor` / `averageGoalsAgainst` - PPG stats

---

#### Get Team Stats (`GET /stats/team/:name`)

```bash
curl "http://127.0.0.1:8080/stats/team/Grand%20Rapids" | jq '.'
```

Returns TeamStats object for a single team.

---

#### Get League Stats (`GET /stats/league`)

```bash
curl "http://127.0.0.1:8080/stats/league" | jq '.'
```

**Response:**
- `totalGamesPlayed` - Total games in database
- `totalTeams` - Number of unique teams
- `dateRange` - Date range of games
- `topTeamsByWinPercentage` - Top 10 teams by win %
- `topTeamsByGoalDifference` - Top 10 teams by goal differential
- `averageGoalsPerGame` - League-wide PPG
- `averageGoalsDifference` - Average margin of victory

---

#### Head-to-Head Record (`GET /stats/head-to-head/:team1/:team2`)

```bash
curl "http://127.0.0.1:8080/stats/head-to-head/Mahtomedi/Delano" | jq '.'
```

**Response:**
- `team1Wins` / `team2Wins` / `ties` - Head-to-head record
- `team1GoalsFor` / `team2GoalsFor` - Total goals in matchups
- `recentGames` - Last 10 games between teams

---

## Feature 4: AI & Machine Learning Endpoints

### 1. Training Data Export (`GET /ai/training-data`)

Export all completed games in ML-friendly format:

```bash
curl "http://127.0.0.1:8080/ai/training-data" | jq '.[0]'
```

**Response Format Per Game:**
```json
{
  "id": "game_list_row_45205875",
  "gameDate": "2026-04-09T00:00:00Z",
  "visitorTeam": "Mahtomedi",
  "homeTeam": "Delano",
  "visitorScore": 4,
  "homeScore": 3,
  "outcome": "VISITOR_WIN",      // HOME_WIN, VISITOR_WIN, TIE
  "goalDifference": 1,
  "totalGoals": 7,
  "location": "...",
  "status": "completed",
  "dataSource": "legacy_hockey",
  "gameURL": "https://..."
}
```

**Features Included:**
- `outcome` - Pre-computed game outcome (for supervised learning)
- `goalDifference` - Goal margin
- `totalGoals` - Total points scored
- `dataSource` - Origin tracking

---

### 2. Training Data Export Formats (`GET /ai/training-data/export`)

```bash
# CSV format
curl "http://127.0.0.1:8080/ai/training-data/export?format=csv" -o training.csv

# JSON array
curl "http://127.0.0.1:8080/ai/training-data/export?format=json" -o training.json

# JSONL (newline-delimited JSON for streaming)
curl "http://127.0.0.1:8080/ai/training-data/export?format=jsonl" -o training.jsonl
```

**CSV Columns:** id, gameDate, visitorTeam, homeTeam, visitorScore, homeScore, outcome, goalDifference, totalGoals, location, status, dataSource

---

### 3. Team Statistics for ML (`GET /ai/team-stats`)

```bash
curl "http://127.0.0.1:8080/ai/team-stats" | jq '.[0]'
```

**Response Format Per Team:**
```json
{
  "teamName": "Grand Rapids",
  "totalGames": 2,
  "wins": 2,
  "losses": 0,
  "ties": 0,
  "goalsFor": 12,
  "goalsAgainst": 4,
  "averageGoalsFor": 6.0,
  "averageGoalsAgainst": 2.0,
  "winRate": 1.0,
  "lastUpdated": "2026-04-09T12:00:00Z"
}
```

**Use Cases:**
- Feature engineering for team strength metrics
- Head-to-head strength comparison
- Time-series trend analysis

---

### 4. League-Wide Context (`GET /ai/league-stats`)

```bash
curl "http://127.0.0.1:8080/ai/league-stats" | jq '.'
```

**Response:**
```json
{
  "dataSource": "legacy_hockey, mn_hockey_hub",
  "fromDate": "2026-04-09T00:00:00Z",
  "toDate": "2026-04-09T00:00:00Z",
  "totalGames": 12,
  "totalTeams": 12,
  "averageGoalsPerGame": 8.0,
  "averageGoalsAgainst": 8.0,
  "homeTeamWinRate": 0.5833,
  "topScoringTeam": "Grand Rapids",
  "lowestScoringTeam": "Delano"
}
```

**Use Cases:**
- Normalization for ML models (league baseline)
- Home field advantage analysis
- Outlier detection

---

## Data Flow for ML Pipeline

### 1. Data Collection
```
Daily Scheduler (6 AM) 
  ↓
FetchAndSaveScoresFromAllSources()
  ↓  
Multi-source aggregation (legacy.hockey + MN Hockey Hub)
  ↓
PostgreSQL Database (with dataSource tracking)
```

### 2. Feature Engineering
```
GET /ai/team-stats
  ↓
Extract features: wins, losses, avg goals, win rate, etc.
  ↓
Can be joined with game data for supervised learning
```

### 3. Training Data Export
```
GET /ai/training-data/export?format=csv|json|jsonl
  ↓
Download as CSV for Excel/Pandas
  ↓
Use with scikit-learn, TensorFlow, PyTorch, etc.
```

### 4. Prediction Serving (Future)
```
/ai/predict?homeTeam=...&visitorTeam=...
  ↓
Returns predicted outcome and confidence scores
```

---

## Example ML Use Cases

### 1. Outcome Prediction
**Goal:** Predict game winner before matchup  
**Features:**
- Team win rates
- Average goals for/against
- Head-to-head history
- Home/away indicators

**Training data available at:** `/ai/training-data` with pre-computed `outcome` field

### 2. Score Prediction
**Goal:** Predict final score  
**Features:**
- Historical team scoring patterns
- Matchup history
- Goal differential trends

**Data export:** `/ai/training-data/export?format=csv`

### 3. Trend Analysis
**Goal:** Identify hot teams, slumps, momentum shifts  
**Data available:**
- Team stats over time
- Sequential game results
- Goal differential trends

### 4. Anomaly Detection
**Goal:** Identify unusual results  
**Metrics:**
- `goalDifference` - Detect blowouts
- `totalGoals` - High-scoring outliers
- Historical baseline comparison

---

## Integration Examples

### Python/Pandas
```python
import pandas as pd
import requests

# Get training data
response = requests.get('http://127.0.0.1:8080/ai/training-data/export?format=csv')
df = pd.read_csv(response.iter_lines(), engine='python')

# Filter by outcome
home_wins = df[df['outcome'] == 'HOME_WIN']
print(f"Home teams won {len(home_wins)} games")

# Get team stats
team_stats = requests.get('http://127.0.0.1:8080/ai/team-stats').json()
stats_df = pd.DataFrame(team_stats)
print(stats_df.sort_values('winRate', ascending=False))
```

### R/Statistical Analysis
```r
library(readr)
library(dplyr)

# Download training data
training_data <- read_csv('http://127.0.0.1:8080/ai/training-data/export?format=csv')

# Summary statistics
training_data %>%
  group_by(outcome) %>%
  summarize(
    avg_goals = mean(totalGoals),
    avg_differential = mean(goalDifference),
    n = n()
  )
```

### JSON Lines for Streaming
```bash
# Process one game at a time
curl "http://127.0.0.1:8080/ai/training-data/export?format=jsonl" | \
  while IFS= read -r line; do
    echo "$line" | jq '.outcome'
  done
```

---

## Database Schema

All data is tracked with multi-source support:

```sql
SELECT * FROM games WHERE status = 'completed'
ORDER BY gameDate DESC;
```

**Key Fields:**
- `dataSource` - "legacy_hockey" or "mn_hockey_hub"
- `externalId` - Original game ID from source
- `gameDate` - Normalized UTC date
- Scores, teams, location, status labels
- URL for source verification

---

## Future Enhancements

1. **Streaming Export** - Real-time game updates via WebSocket
2. **Historical Seasons** - Multi-season trend analysis
3. **Player-Level Stats** - Individual performance metrics
4. **Performance Ranking** - Elo ratings, strength-of-schedule
5. **Predictive API** - Real-time outcome/score predictions
6. **Model Management** - Store/version trained models
7. **Feature Store** - Efficient feature computation and caching

---

## Performance Notes

- **Filtering:** Database-level filtering for source/date/status, client-side for team name
- **Export:** Streaming response generation for large datasets
- **Stats:** In-memory aggregation (fast for dataset size)
- **ML Data:** Fully normalized, no missing required fields
- **Pagination:** Support for large result sets via limit/offset

---

## Errors & Troubleshooting

**Team not found:** Check exact spelling and case (filtered as lowercase contains)
- Use `%20` for spaces in URL: `/stats/team/Grand%20Rapids`

**Export format unavailable:** Ensure `format=csv|json|jsonl`

**No results:** Check date range parameters are valid ISO8601 dates

**Performance issues:** Use pagination (`limit` + `offset`) for large exports
