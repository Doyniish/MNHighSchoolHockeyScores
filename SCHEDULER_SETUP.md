# Daily Scheduler Setup Guide

## Overview

The hockey scores app is now configured to automatically fetch and store game data daily at **6:00 AM UTC**. This ensures your database continuously accumulates historical score data.

## Quick Start

### 1. Install the Scheduler

```bash
cd /Users/tylerliddicoat/Documents/GitHub/MNHighSchoolHockeyScores
chmod +x setup-scheduler.sh
./setup-scheduler.sh
```

This script will:
- ✅ Create a `logs/` directory
- ✅ Build the app
- ✅ Install the launchd agent
- ✅ Activate the scheduler

### 2. Verify Installation

```bash
launchctl list | grep hockeyapi
```

You should see something like:
```
- 0 com.hockeyapi.scorer-daily
```

### 3. View Logs

```bash
# Real-time logs
tail -f logs/scorer.log

# Last 50 lines
tail -50 logs/scorer.log

# Error logs
tail -f logs/scorer-error.log
```

## How It Works

### Scheduler Details

- **Trigger**: Daily at **6:00 AM** (system time)
- **Executable**: `./.build/debug/HockeyScoresAPI`
- **Output**: Logged to `logs/scorer.log`
- **Errors**: Logged to `logs/scorer-error.log`
- **Run duration**: ~5-10 seconds
- **Database**: Saves today's games to PostgreSQL

### What Happens Each Run

1. App starts
2. Connects to PostgreSQL database (must be running)
3. Fetches today's schedule from legacy.hockey
4. Saves all games with today's date
5. App exits
6. Results logged to `logs/scorer.log`

### Example Log Output

```
[ INFO ] Score: Mahtomedi 4 Delano 3 State Class 1A Tournament - Third Place | Grand Casino Arena, St. Paul
[ INFO ] Score: Mankato West 3 St. Cloud Cathedral 6 State Class 1A Tournament - Consolation Championship | 3M Arena at Mariucci, Minneapolis
[ INFO ] Score: Warroad 5 Hibbing/Chisholm 4 State Class 1A Tournament - Championship | Grand Casino Arena, St. Paul
...
[ NOTICE ] Server started on http://127.0.0.1:8080
```

## Management Commands

### Start the Scheduler

```bash
launchctl load ~/Library/LaunchAgents/com.hockeyapi.scheduler.plist
```

### Stop the Scheduler

```bash
launchctl unload ~/Library/LaunchAgents/com.hockeyapi.scheduler.plist
```

### Check Status

```bash
# Is it loaded?
launchctl list | grep hockeyapi

# Last run time
stat ~/Library/LaunchAgents/com.hockeyapi.scheduler.plist | grep Modify
```

### Manually Trigger (For Testing)

```bash
launchctl start com.hockeyapi.scorer-daily
```

### Reload After Changes

If you modify the plist file:

```bash
launchctl unload ~/Library/LaunchAgents/com.hockeyapi.scheduler.plist
sleep 1
launchctl load ~/Library/LaunchAgents/com.hockeyapi.scheduler.plist
```

### Remove the Scheduler

```bash
launchctl unload ~/Library/LaunchAgents/com.hockeyapi.scheduler.plist
rm ~/Library/LaunchAgents/com.hockeyapi.scheduler.plist
```

## Important: Database Must Be Running

The scheduler requires PostgreSQL to be running. Make sure to:

1. **Keep PostgreSQL container running**:

   ```bash
   # Start container if not already running
   docker compose up -d
   ```

2. **Monitor container health**:

   ```bash
   docker compose ps
   ```

If the database isn't running, the app will fail to connect and exit with an error (logged to `logs/scorer-error.log`).

## Troubleshooting

### Scheduler Not Running

1. **Check if loaded**:
   ```bash
   launchctl list | grep hockeyapi
   ```

2. **If not in list, reload it**:
   ```bash
   launchctl load ~/Library/LaunchAgents/com.hockeyapi.scheduler.plist
   ```

3. **Check for errors**:
   ```bash
   tail -50 logs/scorer-error.log
   ```

### App Fails to Connect to Database

**Symptom**: Error log shows connection refused

**Solution**: Ensure PostgreSQL container is running:
```bash
docker compose up -d
docker compose ps
```

### Logs Not Being Generated

**Symptom**: `logs/scorer.log` is empty or doesn't exist

**Solution**: 
1. Verify logs directory exists:
   ```bash
   ls -la logs/
   ```

2. Run the app manually to test:
   ```bash
   ./.build/debug/HockeyScoresAPI
   ```

3. Check launchd logs:
   ```bash
   log show --predicate 'process == "HockeyScoresAPI"' --last 1h
   ```

### App Path Issues

If the plist file has an incorrect path to the executable:

1. Verify the app exists:
   ```bash
   ls -la ./.build/debug/HockeyScoresAPI
   ```

2. Update the plist if needed (path must be absolute):
   ```bash
   # Find full path
   pwd
   # Then update com.hockeyapi.scheduler.plist with correct path
   ```

3. Reload:
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.hockeyapi.scheduler.plist
   sleep 1
   launchctl load ~/Library/LaunchAgents/com.hockeyapi.scheduler.plist
   ```

## Changing the Schedule

To run at a **different time**, edit the plist file:

```bash
# Open in editor
nano ~/Library/LaunchAgents/com.hockeyapi.scheduler.plist
```

Find this section and change the values:

```xml
<key>StartCalendarInterval</key>
<dict>
    <key>Hour</key>
    <integer>6</integer>          <!-- Hour (0-23) -->
    <key>Minute</key>
    <integer>0</integer>           <!-- Minute (0-59) -->
</dict>
```

Then reload:

```bash
launchctl unload ~/Library/LaunchAgents/com.hockeyapi.scheduler.plist
sleep 1
launchctl load ~/Library/LaunchAgents/com.hockeyapi.scheduler.plist
```

## Data Accumulation Example

As the scheduler runs daily, your database grows:

```
Day 1 (April 9):  6 games stored for 2026-04-09 ✓
Day 2 (April 10): 5 games stored for 2026-04-10 ✓
Day 3 (April 11): 0 games stored for 2026-04-11 ✓
...
Day 30: Calendar queries can show data for all 30 days! 📊
```

## macOS System Events

Launchd will:
- ✅ Restart the app if it crashes unexpectedly
- ✅ Skip runs if the system is asleep (waits for wake)
- ✅ Persist across reboots (automatically starts on login)
- ✅ Run in background (no terminal window)

## Additional Resources

- [macOS launchd Documentation](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)
- [Logs Predicate Syntax](https://man.macports.org/man1/log.1)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
