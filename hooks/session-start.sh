#!/bin/bash
# ABOUTME: Session start hook for update checking.
# ABOUTME: Runs check-updates in quiet mode to notify users of available updates.

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HOOK_DIR/.." && pwd)"

# Update check (quiet mode — only prints if update available)
if [ -f "$PLUGIN_ROOT/scripts/check-updates.sh" ]; then
    bash "$PLUGIN_ROOT/scripts/check-updates.sh" --quiet 2>&1 || true
fi

exit 0
