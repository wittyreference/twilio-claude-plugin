#!/bin/bash
# ABOUTME: Logs PermissionDenied events and retries known-safe operations in auto mode.
# ABOUTME: Fires after auto-mode classifier denials; returns {retry:true} for safe paths.

# Claude Code passes tool input as JSON on stdin.
HOOK_INPUT=""
if [ ! -t 0 ]; then
    HOOK_INPUT="$(cat)"
fi

# Observability hook — warn but don't block if jq missing
if [ -n "$HOOK_INPUT" ] && ! command -v jq &> /dev/null; then
    echo "WARNING: jq not installed — permission-denied hook disabled." >&2
    exit 0
fi

# Parse payload
TOOL_NAME=""
FILE_PATH=""
COMMAND=""
HOOK_SESSION_ID=""
if [ -n "$HOOK_INPUT" ] && command -v jq &> /dev/null; then
    TOOL_NAME="$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
    FILE_PATH="$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
    COMMAND="$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
    HOOK_SESSION_ID="$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
fi

# Source helpers for environment detection and event logging
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_emit-event.sh"

# Always log the denial for observability
EMIT_SESSION_ID="${HOOK_SESSION_ID:-unknown}"
emit_event "permission_denied" "$(jq -nc \
    --arg tool "$TOOL_NAME" \
    --arg path "$FILE_PATH" \
    --arg cmd "$COMMAND" \
    '{tool_name:$tool, file_path:$path, command:$cmd}'
)"

# --- Retry logic for Write/Edit denials on known-safe paths ---
if [[ "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" ]] && [ -n "$FILE_PATH" ]; then
    case "$FILE_PATH" in
        # Meta-development files
            echo '{"retry": true}'
            exit 0
            ;;
        # Plan files
        "$HOME/.claude/plans/"*)
            echo '{"retry": true}'
            exit 0
            ;;
        # Memory files
        "$HOME/.claude/memory/"*|"$HOME/.claude/projects/"*)
            echo '{"retry": true}'
            exit 0
            ;;
        # Hook test files
        */.claude/hooks/__tests__/*)
            echo '{"retry": true}'
            exit 0
            ;;
    esac
fi

# --- Retry logic for Bash denials on read-only commands ---
if [[ "$TOOL_NAME" == "Bash" ]] && [ -n "$COMMAND" ]; then
    # Strip leading env var assignments (FOO=bar cmd → cmd)
    BARE_CMD="$(echo "$COMMAND" | sed 's/^[A-Za-z_][A-Za-z0-9_]*=[^ ]* *//')"
    # Get the first word (the actual command)
    FIRST_WORD="$(echo "$BARE_CMD" | awk '{print $1}')"

    case "$FIRST_WORD" in
        ls|cat|head|tail|grep|rg|wc|file|which|echo|pwd|date|whoami|hostname|uname|id|env|printenv|realpath|dirname|basename)
            echo '{"retry": true}'
            exit 0
            ;;
        git)
            # Only retry read-only git subcommands
            SECOND_WORD="$(echo "$BARE_CMD" | awk '{print $2}')"
            case "$SECOND_WORD" in
                status|log|diff|branch|show|rev-parse|ls-files|ls-tree|cat-file|name-rev|describe|shortlog|blame|reflog)
                    echo '{"retry": true}'
                    exit 0
                    ;;
            esac
            ;;
        npm)
            # Only retry read-only npm subcommands
            SECOND_WORD="$(echo "$BARE_CMD" | awk '{print $2}')"
            case "$SECOND_WORD" in
                ls|list|view|info|outdated|audit)
                    echo '{"retry": true}'
                    exit 0
                    ;;
            esac
            ;;
    esac
fi

# Default: denial stands, no retry
exit 0
