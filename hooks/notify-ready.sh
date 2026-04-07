#!/bin/bash
# ABOUTME: Desktop notification hook for when Claude finishes responding.
# ABOUTME: Uses native macOS notifications, Linux notify-send, or terminal bell.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source environment detection helper
source "$SCRIPT_DIR/_meta-mode.sh"
# Cross-platform helpers (portable notifications, etc.)
source "$SCRIPT_DIR/_platform.sh"

# Check for pending documentation actions (environment-aware path)
PENDING_ACTIONS="$CLAUDE_PENDING_ACTIONS"
NOTIFICATION_MSG="Ready for your input"
if [ -f "$PENDING_ACTIONS" ]; then
    ACTION_COUNT=$(grep -c "^\- \[" "$PENDING_ACTIONS" 2>/dev/null || echo "0")
    if [ "$ACTION_COUNT" -gt 0 ]; then
        NOTIFICATION_MSG="Ready - $ACTION_COUNT pending doc action(s)"
    fi
fi

# Send notification (cross-platform: macOS, Linux, Windows Git Bash)
notify_desktop "Claude Code" "$NOTIFICATION_MSG"

exit 0
