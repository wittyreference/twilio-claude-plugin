#!/bin/bash
# ABOUTME: Session start hook for update checking.
# ABOUTME: Runs check-updates in quiet mode to notify users of available updates.

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HOOK_DIR/.." && pwd)"

# Read version from plugin.json
PLUGIN_VERSION=""
if [ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ] && command -v jq &>/dev/null; then
    PLUGIN_VERSION=$(jq -r '.version // empty' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null)
fi

# Welcome message
if [ -n "$PLUGIN_VERSION" ]; then
    echo "Twilio Claude Plugin v${PLUGIN_VERSION} loaded. 310 API tools available." >&2
else
    echo "Twilio Claude Plugin loaded. 310 API tools available." >&2
fi
echo "  Run /preflight to verify setup, /help-twilio to discover skills." >&2

# Update check (quiet mode — only prints if update available)
if [ -f "$PLUGIN_ROOT/scripts/check-updates.sh" ]; then
    bash "$PLUGIN_ROOT/scripts/check-updates.sh" --quiet 2>&1 || true
fi

exit 0
