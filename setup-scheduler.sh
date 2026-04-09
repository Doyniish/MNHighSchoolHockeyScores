#!/bin/bash
# Setup script for daily hockey scores scheduler on macOS

set -e

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLIST_SRC="$PROJECT_DIR/com.hockeyapi.scheduler.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/com.hockeyapi.scheduler.plist"
LOGS_DIR="$PROJECT_DIR/logs"

echo "🏒 Hockey Scores API - Daily Scheduler Setup"
echo ""

# Step 1: Create logs directory
echo "1️⃣  Creating logs directory..."
mkdir -p "$LOGS_DIR"
echo "   Created: $LOGS_DIR"

# Step 2: Build the app
echo ""
echo "2️⃣  Building the application..."
cd "$PROJECT_DIR"
./build.sh > /dev/null 2>&1
echo "   ✓ Build complete"

# Step 3: Copy plist to LaunchAgents
echo ""
echo "3️⃣  Installing scheduler..."
cp "$PLIST_SRC" "$PLIST_DEST"
echo "   Copied to: $PLIST_DEST"

# Step 4: Load the plist
echo ""
echo "4️⃣  Loading launchd job..."
launchctl unload "$PLIST_DEST" 2>/dev/null || true
sleep 1
launchctl load "$PLIST_DEST"
echo "   ✓ Job loaded"

# Step 5: Verify
echo ""
echo "5️⃣  Verifying installation..."
if launchctl list | grep -q "com.hockeyapi.scorer-daily"; then
    echo "   ✓ Scheduler is installed and active"
else
    echo "   ⚠️  Scheduler may not be active"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "The app will run daily at 6:00 AM"
echo ""
echo "📋 Useful commands:"
echo "   View logs:      tail -f '$LOGS_DIR/scorer.log'"
echo "   Check status:   launchctl list | grep hockeyapi"
echo "   Unload job:     launchctl unload '$PLIST_DEST'"
echo "   Reload job:     launchctl load '$PLIST_DEST'"
echo "   Remove job:     rm '$PLIST_DEST' && launchctl unload '$PLIST_DEST'"
