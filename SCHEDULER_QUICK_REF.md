# Quick Reference: Hockey Scores Scheduler

## Check Status
```bash
launchctl list | grep hockeyapi
```

## View Logs (Real-time)
```bash
tail -f logs/scorer.log
```

## View Error Logs
```bash
tail -f logs/scorer-error.log
```

## Manually Test Run
```bash
launchctl start com.hockeyapi.scorer-daily
# Then check logs immediately
```

## Pause Scheduler
```bash
launchctl unload ~/Library/LaunchAgents/com.hockeyapi.scheduler.plist
```

## Resume Scheduler
```bash
launchctl load ~/Library/LaunchAgents/com.hockeyapi.scheduler.plist
```

## Change Schedule Time

Edit: `~/Library/LaunchAgents/com.hockeyapi.scheduler.plist`

Find this section:
```xml
<key>StartCalendarInterval</key>
<dict>
    <key>Hour</key>
    <integer>6</integer>          <!-- Change this for hour (0-23) -->
    <key>Minute</key>
    <integer>0</integer>           <!-- Change this for minute (0-59) -->
</dict>
```

Then reload:
```bash
launchctl unload ~/Library/LaunchAgents/com.hockeyapi.scheduler.plist
sleep 1
launchctl load ~/Library/LaunchAgents/com.hockeyapi.scheduler.plist
```

## Remove Scheduler
```bash
rm ~/Library/LaunchAgents/com.hockeyapi.scheduler.plist
launchctl unload ~/Library/LaunchAgents/com.hockeyapi.scheduler.plist
```

## Current Configuration
- **Status**: ✅ ACTIVE
- **Time**: 6:00 AM daily
- **Logs**: `/logs/scorer.log` + `/logs/scorer-error.log`
- **Requirement**: PostgreSQL must be running (`docker compose up -d`)
