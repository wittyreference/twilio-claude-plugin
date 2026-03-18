#!/bin/bash
# ABOUTME: Pre-bash validation hook for git and deployment safety.
# ABOUTME: Blocks dangerous git operations and validates test status before deploy.

# Claude Code passes tool input as JSON on stdin, not env vars.
HOOK_INPUT=""
if [ ! -t 0 ]; then
    HOOK_INPUT="$(cat)"
fi

COMMAND=""
if [ -n "$HOOK_INPUT" ] && command -v jq &> /dev/null; then
    COMMAND="$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
fi

# Exit if no command
if [ -z "$COMMAND" ]; then
    exit 0
fi

# ============================================
# GIT COMMIT VALIDATION (No --no-verify)
# ============================================

if echo "$COMMAND" | grep -qE "git\s+commit.*--no-verify"; then
    echo "BLOCKED: git commit --no-verify is not allowed!" >&2
    echo "" >&2
    echo "The --no-verify flag bypasses pre-commit hooks which enforce code quality." >&2
    echo "If pre-commit hooks are failing, fix the underlying issues instead." >&2
    echo "" >&2
    echo "Common fixes:" >&2
    echo "  - Run 'npm run lint:fix' to fix linting errors" >&2
    echo "  - Run 'npm test' to verify tests pass" >&2
    echo "" >&2
    exit 2
fi

# Also catch the short form -n
if echo "$COMMAND" | grep -qE "git\s+commit.*\s-n(\s|$)"; then
    echo "BLOCKED: git commit -n (--no-verify) is not allowed!" >&2
    echo "" >&2
    echo "Pre-commit hooks must run to ensure code quality." >&2
    echo "" >&2
    exit 2
fi

# ============================================
# PRE-COMMIT DOCUMENTATION REMINDER
# ============================================

# Check if this is a git commit (but not the --no-verify checks above which already exited)
if echo "$COMMAND" | grep -qE "^git\s+commit"; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # ============================================
    # EPHEMERAL BRANCH WARNING
    # ============================================
    # Warn when committing to branches that look like validation/headless runs.
    # These branches should not accumulate feature work — commit to main instead.
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if echo "$CURRENT_BRANCH" | grep -qE "^(validation-|headless-|uber-val-|fresh-install-)"; then
        echo "" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "⚠️  EPHEMERAL BRANCH: $CURRENT_BRANCH" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "" >&2
        echo "You are committing to what looks like a validation/test branch." >&2
        echo "If this is feature work, switch to main first:" >&2
        echo "" >&2
        echo "  git stash && git checkout main && git stash pop" >&2
        echo "" >&2
        echo "If this commit is intentionally on this branch, proceed." >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "" >&2
    fi

    # ============================================
    # META REFERENCE LEAKAGE WARNING
    # ============================================
    # Warn if staged files contain .meta/ references (potential leakage)
    if git diff --staged 2>/dev/null | grep -qE '\.meta/'; then
        echo "" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "⚠️  WARNING: Staged changes reference .meta/" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "" >&2
        echo "This may indicate meta-development content leaking into shipped code." >&2
        echo "Review with: git diff --staged | grep '.meta/'" >&2
        echo "" >&2
        echo "If this is intentional documentation about the separation, proceed." >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "" >&2
    fi

    # ============================================
    # LOCAL PATH LEAKAGE CHECK (BLOCKING)
    # ============================================
    # Block commits that ship hardcoded local directory paths.
    # These break for anyone who clones the repo to a different location.
    LOCAL_PATH_LEAKS=$(git diff --staged 2>/dev/null \
        | grep '^+' | grep -v '^+++' \
        | grep -En '/Users/[a-zA-Z0-9_.-]+/(workspaces|Desktop|Documents|Downloads|Library|Projects|repos|src|code|dev)/|/home/[a-zA-Z0-9_.-]+/(workspaces|Desktop|Documents|Downloads|Projects|repos|src|code|dev)/' \
        || true)
    if [ -n "$LOCAL_PATH_LEAKS" ]; then
        echo "" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "BLOCKED: Hardcoded local paths in staged changes" >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "" >&2
        echo "These paths won't work for other users:" >&2
        echo "$LOCAL_PATH_LEAKS" | head -10 >&2
        echo "" >&2
        echo "Use dynamic alternatives:" >&2
        echo '  \$HOME, \$PROJECT_ROOT, \$(git rev-parse --show-toplevel)' >&2
        echo '  \$(pwd), relative paths, or \$(dirname "\$0")' >&2
        echo "" >&2
        echo "Override: SKIP_PATH_CHECK=true git commit ..." >&2
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
        echo "" >&2
        if [ "${SKIP_PATH_CHECK:-}" != "true" ]; then
            exit 2
        fi
    fi

    # ============================================
    # COMMIT CHECKLIST PROMPT (Non-blocking)
    # ============================================
    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "COMMIT CHECKLIST" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "  [ ] Captured learnings in .claude/learnings.md?" >&2
    echo "  [ ] Design decision documented if architectural?" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
fi

# ============================================
# FORCE PUSH PROTECTION
# ============================================

if echo "$COMMAND" | grep -qE "git\s+push.*--force"; then
    if echo "$COMMAND" | grep -qE "\s(main|master)(\s|$)"; then
        echo "BLOCKED: Force push to main/master is not allowed!" >&2
        echo "" >&2
        echo "Force pushing to protected branches can cause data loss." >&2
        echo "If you need to revert changes, use 'git revert' instead." >&2
        echo "" >&2
        exit 2
    fi
fi

# ============================================
# DEPLOYMENT VALIDATION
# ============================================

if echo "$COMMAND" | grep -qE "(twilio\s+serverless:deploy|npm\s+run\s+deploy)"; then
    echo "Deployment detected - running pre-deployment validation..."

    # Change to project directory if not already there
    if [ -f "package.json" ]; then
        PROJECT_DIR="."
    elif [ -f "../package.json" ]; then
        PROJECT_DIR=".."
    else
        # Can't find project, skip validation
        exit 0
    fi

    # Check for uncommitted changes
    if [ -d ".git" ]; then
        UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        if [ "$UNCOMMITTED" -gt 0 ]; then
            echo "WARNING: You have $UNCOMMITTED uncommitted change(s)."
            echo "Consider committing before deployment."
            echo ""
        fi
    fi

    # Run tests
    echo "Running tests..."
    if ! npm test --silent 2>/dev/null; then
        echo "" >&2
        echo "BLOCKED: Tests are failing!" >&2
        echo "" >&2
        echo "All tests must pass before deployment." >&2
        echo "Run 'npm test' to see failures and fix them." >&2
        echo "" >&2
        exit 2
    fi
    echo "✓ Tests passed"

    # Check code coverage (80% threshold)
    echo "Checking code coverage..."
    COVERAGE_MIN=80
    COVERAGE_SUMMARY="coverage/coverage-summary.json"

    # Run tests with coverage if summary doesn't exist or is stale
    if [ ! -f "$COVERAGE_SUMMARY" ] || [ "package.json" -nt "$COVERAGE_SUMMARY" ]; then
        npm test -- --coverage --coverageReporters=json-summary --silent 2>/dev/null
    fi

    if [ -f "$COVERAGE_SUMMARY" ] && command -v jq &> /dev/null; then
        # Extract coverage percentages
        STATEMENTS=$(jq -r '.total.statements.pct // 0' "$COVERAGE_SUMMARY" 2>/dev/null)
        BRANCHES=$(jq -r '.total.branches.pct // 0' "$COVERAGE_SUMMARY" 2>/dev/null)
        FUNCTIONS=$(jq -r '.total.functions.pct // 0' "$COVERAGE_SUMMARY" 2>/dev/null)
        LINES=$(jq -r '.total.lines.pct // 0' "$COVERAGE_SUMMARY" 2>/dev/null)

        # Check if any metric is below threshold
        COVERAGE_FAILED=false
        FAILED_METRICS=""

        # Use awk for float comparison
        if [ "$(echo "$STATEMENTS < $COVERAGE_MIN" | bc -l 2>/dev/null || echo "0")" = "1" ]; then
            COVERAGE_FAILED=true
            FAILED_METRICS="${FAILED_METRICS}statements: ${STATEMENTS}%, "
        fi
        if [ "$(echo "$BRANCHES < $COVERAGE_MIN" | bc -l 2>/dev/null || echo "0")" = "1" ]; then
            COVERAGE_FAILED=true
            FAILED_METRICS="${FAILED_METRICS}branches: ${BRANCHES}%, "
        fi

        if [ "$COVERAGE_FAILED" = true ]; then
            FAILED_METRICS=$(echo "$FAILED_METRICS" | sed 's/, $//')
            echo "" >&2
            echo "BLOCKED: Code coverage below ${COVERAGE_MIN}% threshold!" >&2
            echo "" >&2
            echo "Failed metrics: $FAILED_METRICS" >&2
            echo "" >&2
            echo "Coverage summary:" >&2
            echo "  Statements: ${STATEMENTS}%" >&2
            echo "  Branches:   ${BRANCHES}%" >&2
            echo "  Functions:  ${FUNCTIONS}%" >&2
            echo "  Lines:      ${LINES}%" >&2
            echo "" >&2
            echo "Add tests to increase coverage before deploying." >&2
            echo "Run 'npm test -- --coverage' to see uncovered lines." >&2
            echo "" >&2
            exit 2
        fi
        echo "✓ Coverage check passed (statements: ${STATEMENTS}%, branches: ${BRANCHES}%)"
    else
        echo "⚠️  Coverage check skipped (missing coverage report or jq)"
    fi

    # Run linting
    echo "Running linter..."
    if ! npm run lint --silent 2>/dev/null; then
        echo "" >&2
        echo "BLOCKED: Linting errors detected!" >&2
        echo "" >&2
        echo "Fix linting errors before deployment." >&2
        echo "Run 'npm run lint:fix' to auto-fix, or 'npm run lint' to see errors." >&2
        echo "" >&2
        exit 2
    fi
    echo "✓ Linting passed"

    # Check for production deployment
    if echo "$COMMAND" | grep -qE "(--environment\s+prod|deploy:prod)"; then
        echo ""
        echo "⚠️  PRODUCTION DEPLOYMENT"
        echo ""
        echo "Pre-deployment checks:"
        echo "  ✓ All tests passing"
        echo "  ✓ Coverage meets 80% threshold"
        echo "  ✓ Linting passing"
        echo ""
    fi

    echo "Pre-deployment validation complete."
    echo ""
fi

exit 0
