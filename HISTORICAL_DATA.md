# Historical Data Backfill Guide

## How Historical Data Works

The Hockey Scores app stores each day's games as they're fetched from legacy.hockey. Since legacy.hockey only provides the **current day's schedule**, the app builds historical data over time as it runs.

### Timeline:
- **Day 1** (April 8): App runs → Saves April 8 schedule to database
- **Day 2** (April 9): App runs → Saves April 9 schedule to database  
- **Day 3+**: Each day continues to save that day's schedule

When you use the calendar to view past dates, it shows games **only for dates when the app has stored data**.

## Viewing Historical Data

Use the app each day during the hockey season to build up historical data. For example:
- Tomorrow's calendar date will show today's games
- Dates the app ran on will have their games available
- Dates the app didn't run on will show no games

## Database Management

### Check what dates have games:
```bash
docker exec mnhighschoolhockeyscores-db-1 psql -U vapor_username -d vapor_database -c \
  "SELECT DISTINCT gameDate FROM games ORDER BY gameDate DESC;"
```

### Clear all data and start fresh:
```bash
docker compose down -v
./start-db.sh
./build.sh run
```

### View games for a specific date:
```bash
docker exec mnhighschoolhockeyscores-db-1 psql -U vapor_username -d vapor_database -c \
  "SELECT gameDate, visitorTeam, visitorScore, homeTeam, homeScore FROM games WHERE gameDate::date = '2026-04-09' ORDER BY gameDate;"
```

---

The app is working correctly - it's building historical data as it runs!
