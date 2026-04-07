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
# VALUE LEAKAGE DETECTION (post-commit)
# ============================================
# After a successful git commit, check if committed files are in sync maps.
# Files not mapped (and not excluded) are potential value leakage candidates.

    _detect_value_leakage() {

        # Noise filters: skip ephemeral branches
        local BRANCH
        BRANCH=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)
        case "$BRANCH" in
            validation-*|headless-*|uber-val-*|fresh-install-*) return 0 ;;
        esac

        # Get committed files from the most recent commit
        local COMMITTED_FILES
        COMMITTED_FILES=$(git -C "$PROJECT_ROOT" diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null)
        [ -z "$COMMITTED_FILES" ] && return 0

        local HAS_SYNCABLE=false
        while IFS= read -r file; do
            case "$file" in
                __tests__/*|*.test.*|*.spec.*) continue ;;
                .claude/skills/*|.claude/commands/*|.claude/hooks/*|.claude/rules/*|.claude/references/*) HAS_SYNCABLE=true ;;
                functions/*/CLAUDE.md|functions/*/REFERENCE.md) HAS_SYNCABLE=true ;;
                scripts/*.sh) HAS_SYNCABLE=true ;;
            esac
        done <<< "$COMMITTED_FILES"
        [ "$HAS_SYNCABLE" = "false" ] && return 0

        # Build list of all mapped + excluded paths from both sync maps
        local FF_MAP="$PROJECT_ROOT/../feature-factory/ff-sync-map.json"
        local KNOWN_PATHS=""

        if [ -f "$PLUGIN_MAP" ]; then
            # Extract all factory paths from mappings and all excluded paths
            local PLUGIN_MAPPED PLUGIN_EXCLUDED
            PLUGIN_MAPPED=$(jq -r '[.mappings[][]? | .factory // empty] | .[]' "$PLUGIN_MAP" 2>/dev/null)
            PLUGIN_EXCLUDED=$(jq -r '[.excluded[][]? // empty] | .[]' "$PLUGIN_MAP" 2>/dev/null)
            KNOWN_PATHS="$PLUGIN_MAPPED"$'\n'"$PLUGIN_EXCLUDED"
        fi

        if [ -f "$FF_MAP" ]; then
            local FF_MAPPED FF_EXCLUDED
            FF_MAPPED=$(jq -r '[.mappings[][]? | .source // empty] | .[]' "$FF_MAP" 2>/dev/null)
            FF_EXCLUDED=$(jq -r '[.excluded[][]? // empty] | .[]' "$FF_MAP" 2>/dev/null)
            KNOWN_PATHS="$KNOWN_PATHS"$'\n'"$FF_MAPPED"$'\n'"$FF_EXCLUDED"
        fi

        # Check each syncable committed file against known paths
        local CANDIDATES=()
        local COMMIT_SHA
        COMMIT_SHA=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null)

        while IFS= read -r file; do
            # Only check syncable directories
            case "$file" in
                .claude/skills/*|.claude/commands/*|.claude/hooks/*|.claude/rules/*|.claude/references/*) ;;
                functions/*/CLAUDE.md|functions/*/REFERENCE.md) ;;
                scripts/*.sh) ;;
                *) continue ;;
            esac
            # Skip if file is in known paths (mapped or excluded)
            if echo "$KNOWN_PATHS" | grep -qxF "$file"; then
                continue
            fi
            CANDIDATES+=("$file")
        done <<< "$COMMITTED_FILES"

        [ ${#CANDIDATES[@]} -eq 0 ] && return 0

        # Determine which sync maps are missing each candidate
        mkdir -p "$PENDING_DIR" 2>/dev/null
        local TIMESTAMP
        TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

        local FILES_JSON
        FILES_JSON=$(printf '%s\n' "${CANDIDATES[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')

        # Write pending entry
        jq -nc \
            --arg commit "$COMMIT_SHA" \
            --arg ts "$TIMESTAMP" \
            --argjson files "$FILES_JSON" \
            '{commit:$commit, timestamp:$ts, files:$files, reviewed:false}' \
            >> "$PENDING_DIR/pending.jsonl"

        # Emit structured event
        local HOOK_DIR
        HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        source "$HOOK_DIR/_emit-event.sh"
        EMIT_SESSION_ID="$_POST_BASH_SESSION_ID"
        emit_event "value_leakage_candidate" "$(jq -nc \
            --arg commit "$COMMIT_SHA" \
            --argjson files "$FILES_JSON" \
            --arg count "${#CANDIDATES[@]}" \
            '{commit:$commit, files:$files, count:($count|tonumber)}')"

        echo "[VALUE] ${#CANDIDATES[@]} file(s) not in any sync map — run /value-audit to review" >&2
    }
    _detect_value_leakage
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
