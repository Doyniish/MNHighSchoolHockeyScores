# Docker Desktop Setup for macOS

## Install Docker Desktop

### Method 1: Direct Download (Easiest)
1. Go to https://www.docker.com/products/docker-desktop
2. Click **Download for Mac**
3. Choose the correct version:
   - **Apple Silicon** (M1/M2/M3 chips) → `Docker.dmg` (Apple Silicon)
   - **Intel Mac** → `Docker.dmg` (Intel Chip)
4. Open the downloaded `.dmg` file
5. Drag Docker icon to Applications folder
6. Open Applications → Double-click Docker.app
7. Enter your Mac password when prompted
8. Wait for Docker to start (look for the Docker menu at top-right)

### Method 2: Via Homebrew (If you have it)
```bash
brew install docker --cask
```

## Verify Installation
Once Docker Desktop is running, test it:
```bash
docker --version
docker compose version
```

Both should show version numbers.

## Next Steps
Once Docker is installed, run:
```bash
cd /Users/tylerliddicoat/Documents/GitHub/MNHighSchoolHockeyScores
./start-db.sh
```

This will start PostgreSQL automatically. Your app will then be able to:
- Store all game scores in the database
- Show historical scores when you change the calendar date
- Persist data even after restarting

## Troubleshooting
- If Docker won't start: Restart your Mac
- If permission denied: Make sure Docker Desktop is running
- Check Docker status: `docker ps`
