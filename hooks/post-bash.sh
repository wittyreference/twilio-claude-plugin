#!/bin/bash
# ABOUTME: Post-bash hook for tracking command completions.
# ABOUTME: Logs deployment completions and sends notifications for key operations.

# ============================================
# PARSE TOOL INPUT FROM STDIN
# ============================================
# Claude Code passes tool input as JSON on stdin, not env vars.
# Capture it before anything else consumes stdin.
_POST_BASH_HOOK_INPUT=""
if [ ! -t 0 ]; then
    _POST_BASH_HOOK_INPUT="$(cat)"
fi

COMMAND=""
_POST_BASH_SESSION_ID=""
if [ -n "$_POST_BASH_HOOK_INPUT" ] && ! command -v jq &> /dev/null; then
    echo "WARNING: jq not installed — post-bash hooks disabled (deployment tracking)." >&2
    if command -v brew &>/dev/null; then echo "  Install: brew install jq" >&2
    elif command -v apt-get &>/dev/null; then echo "  Install: sudo apt-get install -y jq" >&2
    else echo "  Install jq: https://jqlang.github.io/jq/download/" >&2; fi
fi
if [ -n "$_POST_BASH_HOOK_INPUT" ] && command -v jq &> /dev/null; then
    COMMAND="$(echo "$_POST_BASH_HOOK_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
    _POST_BASH_SESSION_ID="$(echo "$_POST_BASH_HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
fi

# Exit if no command
if [ -z "$COMMAND" ]; then
    exit 0
fi

# ============================================
# ENVIRONMENT SETUP
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Cross-platform helpers (portable notifications, etc.)
source "$SCRIPT_DIR/_platform.sh"

# ============================================
# TOOL-CALL COUNTER (context pressure awareness)
# ============================================
if [ -n "$_POST_BASH_SESSION_ID" ]; then
    _BASH_SESSION_DIR="$(dirname "$CLAUDE_PENDING_ACTIONS")"
    _BASH_SESSIONS_DIR="$_BASH_SESSION_DIR/.sessions"
    mkdir -p "$_BASH_SESSIONS_DIR"
    COUNTER_FILE="$_BASH_SESSIONS_DIR/${_POST_BASH_SESSION_ID}.tool-calls"
    COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
    COUNT=$((COUNT + 1))
    echo "$COUNT" > "$COUNTER_FILE"
    if [ $((COUNT % 50)) -eq 0 ]; then
        echo "Context checkpoint: $COUNT tool calls this session." >&2
    fi
fi

# ============================================
# WORKTREE LAST-ACTIVE KEEPALIVE
# ============================================
# Update .last-active timestamp so worktree-status.sh can accurately
# detect stale vs active worktrees. Throttled to once per 60s.

_PB_GIT_DIR=$(git rev-parse --git-dir 2>/dev/null || echo "")
if echo "$_PB_GIT_DIR" | grep -q '/worktrees/'; then
    _PB_WT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$_PB_WT_ROOT" ]; then
        _PB_LAST_ACTIVE="$_PB_WT_ROOT/.last-active"
        _PB_NOW=$(date +%s)
        _PB_LAST_TS=$(head -1 "$_PB_LAST_ACTIVE" 2>/dev/null || echo "0")
        if [ $(( _PB_NOW - _PB_LAST_TS )) -gt 60 ] 2>/dev/null; then
            echo "$_PB_NOW" > "$_PB_LAST_ACTIVE"
        fi
    fi
fi

# ============================================
# DEPLOYMENT COMPLETION
# ============================================

if echo "$COMMAND" | grep -qE "(twilio\s+serverless:deploy|npm\s+run\s+deploy)"; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Deployment command completed."
    echo "Check the output above for deployed URLs."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Send desktop notification (cross-platform)
    notify_desktop "Claude Code" "Deployment complete - check terminal for URLs"
fi

# ============================================
# TEST/BUILD COMPLETION - Doc reminder
# ============================================

# After tests or builds complete is a great time to remind about docs
# because significant work was just completed and verified
if echo "$COMMAND" | grep -qE "(npm\s+(test|run\s+(test|build))|jest|vitest)"; then
    # Get project root from script location
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [ -x "$FLYWHEEL_HOOK" ]; then
        "$FLYWHEEL_HOOK" --force
    fi
fi

# ============================================
# STRUCTURED EVENT EMISSION (observability)
# ============================================

if [ -z "$SCRIPT_DIR" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
source "$SCRIPT_DIR/_emit-event.sh"
EMIT_SESSION_ID="$_POST_BASH_SESSION_ID"

# Emit bash_command event for every command
emit_event "bash_command" "$(jq -nc --arg cmd "$COMMAND" '{command: $cmd}')"

# Emit specialized test_run event when tests are run
if echo "$COMMAND" | grep -qE "(npm\s+(test|run\s+test)|jest|vitest)"; then
    emit_event "test_run" "$(jq -nc --arg cmd "$COMMAND" '{command: $cmd}')"
fi

# Emit deploy event when deployment commands are run
if echo "$COMMAND" | grep -qE "(twilio\s+serverless:deploy|npm\s+run\s+deploy)"; then
    emit_event "deploy" "$(jq -nc --arg cmd "$COMMAND" '{command: $cmd}')"
fi

exit 0
