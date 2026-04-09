# Historical Score Storage & Retrieval

## Current Implementation

The app now supports querying games by specific date through the `/scores/:year/:month/:day` endpoint. Games are stored in PostgreSQL and persisted for historical reference.

## From the UI Perspective

- Navigate the calendar to any date (e.g., April 9th, 2026)
- Click a date and the app will query the database for games on that date
- If games exist in the database from that date, they'll be displayed
- If no games are found for that date, an empty list is returned

## How Data Gets Populated

### Automatic Population
1. **On app startup**: The app fetches today's schedule from legacy.hockey and saves all games with today's date to the database
2. **Each time `/scores` is called**: Fresh games are fetched and stored with today's date
3. **Once stored**: Games can be queried for that specific date indefinitely

### Example Timeline
- **April 9, 2026 (today)**: App runs → fetches 6 games from legacy.hockey → stores games with date 2026-04-09 in database
  - `/scores` returns 6 games ✓
  - `/scores/2026/04/09` returns 6 games ✓
  - `/scores/2026/04/08` returns 0 games (app didn't run yesterday)

### Historical Data Limitation

The legacy.hockey API **does not support date parameters**. It only returns the current day's schedule. This means:

- **Data accumulates over time**: Each day the app runs, new games are captured
- **Past dates show games only if previously captured**: If the app wasn't running on April 8, there's no automatic way to backfill April 8th's schedule
- **Two approaches**:
  1. **Time-based accumulation (current)**: Run the app daily and it builds a growing historical database
  2. **Manual backfill (if needed)**: Import historical game data from another source or CSV

## Database Schema

Games are stored in the `games` table with:
- `gameDate`: The date of the game (stored as SQL DATE, normalized to midnight UTC)
- `externalId`: Unique game ID from legacy.hockey
- `visitorTeam`, `visitorScore`: Away team info
- `homeTeam`, `homeScore`: Home team info
- `location`, `status`, `statusLabel`: Game metadata
- `gameURL`: Link to the game on legacy.hockey

### Unique Constraint
A UNIQUE constraint on `(externalId, gameDate)` prevents duplicate entries for the same game.

## API Behavior

| Endpoint | Source | When It Works |
|----------|--------|---------------|
| `/scores` | Legacy.hockey (fresh) + Database | Always - fetches today, returns all in DB |
| `/scores/2026/04/09` | Database only | Only if app previously fetched data for that date |
| `/scores/team/Edina` | Legacy.hockey (fresh) + filters | Always - fetches today's schedule tofiltered by team |

## Solution: Daily Scheduled Execution

For a production deployment, the app should be scheduled to run daily (e.g., via cron, systemd timer, or cloud scheduler):

```bash
# Every day at 6 AM UTC
0 6 * * * /path/to/.build/debug/HockeyScoresAPI
```

This ensures games are automatically captured and available for calendar queries going forward.

## Technical Details

### Date Normalization
Dates are stored at midnight UTC to ensure consistent date-based querying:
- Input: `2026/04/09` (any timezone)
- Stored: `2026-04-09` (midnight UTC)
- Query range: `>= 2026-04-09 00:00:00` AND `< 2026-04-10 00:00:00`

### Query Implementation
```swift
// The date-specific route uses DateRange filtering
GET /scores/:year/:month/:day
- Constructs a Date for midnight on the requested date
- Queries: gameDate >= targetDate AND gameDate < nextDay
- Returns all matching Game models converted to ScoreItem format
```

## Future Enhancement Ideas

1. **Scheduled data fetch**: Background service that runs daily to capture scores
2. **CSV import**: Upload historical game data from a CSV file
3. **cron integration**: Use a job scheduler (e.g., Swift for server-side scheduling)
4. **Cache strategy**: Cache today's results and refresh at set intervals
