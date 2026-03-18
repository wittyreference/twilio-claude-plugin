#!/bin/bash
# ABOUTME: Stop hook that checks for open session hygiene items.
# ABOUTME: Reminds about learnings, docs, uncommitted work, unpushed commits, and test runs.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# ============================================
# Collect checklist items
# ============================================
ITEMS=()

# --- 1. Uncommitted changes ---
UNCOMMITTED=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [[ "$UNCOMMITTED" -gt 0 ]]; then
    ITEMS+=("UNCOMMITTED: $UNCOMMITTED file(s) with uncommitted changes")
fi

# --- 2. Unpushed commits ---
UNPUSHED=$(git -C "$PROJECT_ROOT" log --oneline '@{upstream}..HEAD' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$UNPUSHED" -gt 0 ]]; then
    ITEMS+=("UNPUSHED: $UNPUSHED commit(s) not pushed to remote")
fi

# --- 3. Learnings freshness ---
# Check if the learnings file was modified during this session (within last 4 hours)
LEARNINGS_FILE="$PROJECT_ROOT/.claude/learnings.md"
if [[ -f "$LEARNINGS_FILE" ]]; then
    LEARN_MTIME=$(stat -f %m "$LEARNINGS_FILE" 2>/dev/null || stat -c %Y "$LEARNINGS_FILE" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    LEARN_AGE=$(( NOW - LEARN_MTIME ))
    if [[ $LEARN_AGE -gt 14400 ]]; then
        ITEMS+=("LEARNINGS: Learnings file not updated this session — capture any discoveries to $LEARNINGS_FILE")
    fi
else
    ITEMS+=("LEARNINGS: No learnings file found — consider creating $LEARNINGS_FILE")
fi

# --- 4. Test recency ---
# Check if tests were run in this session by looking for recent jest cache or test output
# Use git log to see if any code changed since last test-related commit
LAST_TEST_COMMIT=$(git -C "$PROJECT_ROOT" log --oneline --all --grep="test" -1 --format="%H" 2>/dev/null || echo "")
if [[ -n "$LAST_TEST_COMMIT" ]]; then
    # Check if source files changed since that commit
    CHANGED_SINCE_TEST=$(git -C "$PROJECT_ROOT" diff --name-only "$LAST_TEST_COMMIT" -- '*.ts' '*.js' '*.json' 2>/dev/null | grep -v node_modules | grep -v dist | wc -l | tr -d ' ')
    if [[ "$CHANGED_SINCE_TEST" -gt 5 ]]; then
        ITEMS+=("TESTS: $CHANGED_SINCE_TEST source files changed since last test commit — consider running npm test")
    fi
fi

# --- 5. E2E test reminder (if functional code was modified) ---
FUNCTIONS_CHANGED=$(git -C "$PROJECT_ROOT" diff --name-only HEAD 2>/dev/null | grep -c '^functions/') || FUNCTIONS_CHANGED=0
if [[ "$FUNCTIONS_CHANGED" -gt 0 ]]; then
    ITEMS+=("E2E: $FUNCTIONS_CHANGED function file(s) modified — consider running npm run test:e2e")
fi

# --- 6. MEMORY.md size check ---
MEMORY_FILE="$HOME/.claude/projects/$(echo "$PROJECT_ROOT" | sed 's|/|-|g')/memory/MEMORY.md"
if [[ -f "$MEMORY_FILE" ]]; then
    MEMORY_LINES=$(wc -l < "$MEMORY_FILE" | tr -d ' ')
    if [[ "$MEMORY_LINES" -gt 100 ]]; then
        ITEMS+=("MEMORY: ${MEMORY_LINES}/200 lines — consider pruning stale entries")
    fi
fi

# --- 7. README drift check ---
README_DRIFT_SCRIPT="$PROJECT_ROOT/scripts/check-readme-drift.sh"
if [[ -x "$README_DRIFT_SCRIPT" ]]; then
    DRIFT_OUTPUT=$("$README_DRIFT_SCRIPT" --quiet 2>/dev/null) || true
    if [[ -n "$DRIFT_OUTPUT" ]]; then
        ITEMS+=("README: $DRIFT_OUTPUT")
    fi
fi

# ============================================
# Output checklist (only if there are items)
# ============================================
if [[ ${#ITEMS[@]} -gt 0 ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "SESSION CHECKLIST"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    for item in "${ITEMS[@]}"; do
        echo "  - $item"
    done
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi

exit 0
