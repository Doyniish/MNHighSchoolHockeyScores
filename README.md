# HockeyScoresAPI

💧 A project built with the Vapor web framework.

## Overview

This API fetches Minnesota high school hockey scores from [legacy.hockey](https://legacy.hockey) and provides multiple endpoints for querying games by date and team. Scores are persisted in PostgreSQL for historical reference.

## Database Setup

### Using Docker (Recommended)

For local development with PostgreSQL running in Docker:

```bash
# Start PostgreSQL container
docker compose up -d

# Run database migrations
./.build/debug/HockeyScoresAPI migrate
```

### Manual PostgreSQL Setup

If you have PostgreSQL installed locally:

```bash
# Create a database and user
createdb vapor_database
createuser vapor_username
psql -U postgres -d vapor_database -c "ALTER USER vapor_username WITH PASSWORD 'vapor_password';"
psql -U postgres -d vapor_database -c "GRANT ALL PRIVILEGES ON DATABASE vapor_database TO vapor_username;"

# Run migrations
./.build/debug/HockeyScoresAPI migrate
```

### Environment Variables

Configure the database connection using environment variables:

```bash
export DATABASE_HOST=localhost
export DATABASE_PORT=5432
export DATABASE_USERNAME=vapor_username
export DATABASE_PASSWORD=vapor_password
export DATABASE_NAME=vapor_database
```

## Building

To build the project, run the build script from the root:

```bash
./build.sh
```

This script handles C++ SDK configuration needed for dependencies like swift-nio-ssl. If using Linux/other platforms, `swift build` should work without the script.

## Running

### Start the server:

```bash
./.build/debug/HockeyScoresAPI
```

The server will start on `http://127.0.0.1:8080`

### Or use the build script's convenience option:

```bash
./build.sh run
```

## API Endpoints

### Get today's scores
```
GET /scores
```
Returns all games for today, fetching fresh data from legacy.hockey and saving to the database.

### Get scores for a specific date
```
GET /scores/:year/:month/:day
```
Returns games stored in the database for the requested date. Dates must be in YYYY/MM/DD format (e.g., `/scores/2026/04/09`).

**Historical Data Note:** The legacy.hockey API only provides the current day's schedule. Games are automatically saved to the database when `/scores` is called or at server startup. To see games for past dates, the app must have been running on those dates previously, or you can manually populate the database.

### Filter by team (today's games)
```
GET /scores/team/:name
```
Returns today's games filtered by team name (case-insensitive contains match).

### Filter by multiple teams (URL-encoded)
```
GET /scores/teams?names=Team1,Team2,Team3
```
Returns today's games for the specified teams.

## Response Format

```json
[
  {
    "id": "game_list_row_45205875",
    "visitorTeam": "Mahtomedi",
    "visitorScore": 4,
    "homeTeam": "Delano",
    "homeScore": 3,
    "status": "completed",
    "statusLabel": "Final/OT",
    "location": "Grand Casino Arena, St. Paul",
    "gameURL": "https://www.legacy.hockey/game/show/45205875",
    "rawLine": "Mahtomedi 4 - 3 Delano"
  }
]
```

## Testing

To execute tests:

```bash
swift test
```

## See More

- [Vapor Website](https://vapor.codes)
- [Vapor Documentation](https://docs.vapor.codes)
- [Vapor GitHub](https://github.com/vapor)
- [Vapor Community](https://github.com/vapor-community)
