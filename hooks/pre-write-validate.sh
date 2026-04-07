#!/bin/bash
# ABOUTME: Pre-write validation hook for credential safety, ABOUTME, and meta isolation.
# ABOUTME: Blocks writes containing hardcoded credentials, missing headers, or violating meta mode.
#
# META MODE BYPASS: Use Bash with inline env var to write to production paths:
#   CLAUDE_ALLOW_PRODUCTION_WRITE=true cat > functions/path/file.js << 'EOF'
#   ...
#   EOF

# Claude Code passes tool input as JSON on stdin, not env vars.
HOOK_INPUT=""
if [ ! -t 0 ]; then
    HOOK_INPUT="$(cat)"
fi

FILE_PATH=""
CONTENT=""
if [ -n "$HOOK_INPUT" ] && ! command -v jq &> /dev/null; then
    echo "BLOCKED: jq not installed — safety hooks cannot run (credential detection, pipeline gate, ABOUTME)." >&2
    if command -v brew &>/dev/null; then echo "  Install: brew install jq" >&2
    elif command -v apt-get &>/dev/null; then echo "  Install: sudo apt-get install -y jq" >&2
    else echo "  Install jq: https://jqlang.github.io/jq/download/" >&2; fi
    echo "  See .claude/references/hook-troubleshooting.md for details." >&2
    exit 2
fi
if [ -n "$HOOK_INPUT" ] && command -v jq &> /dev/null; then
    FILE_PATH="$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
    CONTENT="$(echo "$HOOK_INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)"
    OLD_STRING="$(echo "$HOOK_INPUT" | jq -r '.tool_input.old_string // empty' 2>/dev/null)"
fi

# Exit early if no content to validate — unless this is a learnings.md edit
# (Edit operations clearing learnings.md have empty new_string, which is
# exactly the case the learnings archival guard needs to catch)
if [ -z "$CONTENT" ] && [[ ! "$FILE_PATH" =~ learnings\.md$ ]]; then
    exit 0
fi

# ============================================
# META-MODE ISOLATION CHECK
# ============================================

# Source meta-mode detection
HOOK_DIR="$(dirname "$0")"
if [ -f "$HOOK_DIR/_meta-mode.sh" ]; then
fi

# Lazy bypass event logger — sources _emit-event.sh on first call only
_log_bypass() {
    local var_name="$1" tier="$2" context="$3"
    if [ -z "${_BYPASS_LOGGER_INIT:-}" ]; then
        if [ -f "$HOOK_DIR/_emit-event.sh" ]; then
            source "$HOOK_DIR/_emit-event.sh"
            EMIT_SESSION_ID="$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null)"
        fi
        _BYPASS_LOGGER_INIT=1
    fi
    emit_event "bypass_used" "$(jq -nc         --arg var "$var_name"         --arg tier "$tier"         --arg ctx "$context"         '{bypass_var:$var, tier:$tier, context:$ctx}' 2>/dev/null)" 2>/dev/null || true
}

# Check meta-mode isolation (can be bypassed with CLAUDE_ALLOW_PRODUCTION_WRITE=true)
    # Get project root for path comparison
    PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

    # Resolve symlinks in both paths to handle macOS /tmp → /private/tmp
    # For new files, resolve directory portion (file doesn't exist yet)
    _META_DIR="$(dirname "$FILE_PATH")"
    _META_RESOLVED_DIR="$(realpath "$_META_DIR" 2>/dev/null || echo "$_META_DIR")"
    RESOLVED_FILE_PATH="$_META_RESOLVED_DIR/$(basename "$FILE_PATH")"
    RESOLVED_PROJECT_ROOT="$(realpath "$PROJECT_ROOT" 2>/dev/null || echo "$PROJECT_ROOT")"

    # Compute relative path from both resolved and raw FILE_PATH.
    # FILE_PATH is guaranteed absolute (CC v2.1.88+) but not symlink-resolved.
    # realpath resolves it outside PROJECT_ROOT, breaking the prefix strip.
    # Fall back to the raw FILE_PATH (relative to PROJECT_ROOT) for pattern matching.
    RELATIVE_PATH="${RESOLVED_FILE_PATH#$RESOLVED_PROJECT_ROOT/}"
    if [[ "$RELATIVE_PATH" == "$RESOLVED_FILE_PATH" ]]; then
        # Resolved path is outside project root — use raw path instead
        RELATIVE_PATH="${FILE_PATH#$RESOLVED_PROJECT_ROOT/}"
        # If strip failed, try with unresolved PROJECT_ROOT
        # (handles case where PROJECT_ROOT itself is under a symlink)
        if [[ "$RELATIVE_PATH" == "$FILE_PATH" ]]; then
            RELATIVE_PATH="${FILE_PATH#$PROJECT_ROOT/}"
        fi
    fi

    # Only enforce meta-mode isolation for files INSIDE the project root.
    # Files outside (e.g., ~/.claude/plans/, ~/.claude/memory/) are not
    # production code — credential checks below still apply to them.
    if [[ "$RELATIVE_PATH" != "$FILE_PATH" ]]; then
        # Allowed paths in meta mode
        # - .claude/* - Claude Code configuration (hooks, plans, etc.)
        # - scripts/* - development scripts (often need updating)
        # - __tests__/* - test files (part of development)
        # - *.md in root - documentation files

        ALLOWED=false
        case "$RELATIVE_PATH" in
                ALLOWED=true
                ;;
            .claude/*)
                ALLOWED=true
                ;;
            scripts/*)
                ALLOWED=true
                ;;
            .github/*)
                ALLOWED=true
                ;;
            __tests__/*)
                ALLOWED=true
                ;;
            agents/*)
                ALLOWED=true
                ;;
            .env|.env.*)
                # .env files are gitignored local config, not production code
                ALLOWED=true
                ;;
            */CLAUDE.md)
                # Domain CLAUDE.md files are development documentation, not production code
                ALLOWED=true
                ;;
            *.md)
                # Root-level markdown files are docs
                if [[ "$RELATIVE_PATH" != */* ]]; then
                    ALLOWED=true
                fi
                ;;
        esac

        if [ "$ALLOWED" = "false" ]; then
            echo "BLOCKED: Meta mode active - changes to production code blocked!" >&2
            echo "" >&2
            echo "" >&2
            echo "Attempted to write: $RELATIVE_PATH" >&2
            echo "" >&2
            echo "Allowed paths in meta mode:" >&2
            echo "  - .claude/plans/*" >&2
            echo "  - .claude/archive/*" >&2
            echo "" >&2
            echo "To intentionally promote changes to production code:" >&2
            echo "  export CLAUDE_ALLOW_PRODUCTION_WRITE=true" >&2
            echo "" >&2
            echo "" >&2
            exit 2
        fi
    fi
    _log_bypass "CLAUDE_ALLOW_PRODUCTION_WRITE" "1" "meta-mode isolation bypassed for: ${FILE_PATH##*/}"
fi

# ============================================
# WORKTREE ISOLATION CHECK (BLOCKING)
# ============================================
# Sessions that write code MUST use a worktree. Concurrent sessions on the main
# tree cause merge conflicts and silent overwrites. Exempt: plans, logs, learnings,
# .meta, and other session-infrastructure paths that don't affect production code.
# Bypass: CLAUDE_ALLOW_MAIN_WRITE=true

if [ "${CLAUDE_ALLOW_MAIN_WRITE:-}" != "true" ] && [ "${CI:-}" != "true" ]; then
    PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
    _GIT_COMMON="$(git rev-parse --git-dir 2>/dev/null || echo "")"

    # Not in a worktree if git-dir does NOT contain /worktrees/
    if [ -n "$_GIT_COMMON" ] && ! echo "$_GIT_COMMON" | grep -q '/worktrees/'; then
        # Check if file is inside the repo
        _WC_DIR="$(dirname "$FILE_PATH")"
        _WC_RESOLVED_DIR="$(realpath "$_WC_DIR" 2>/dev/null || echo "$_WC_DIR")"
        _WC_RESOLVED_FILE="$_WC_RESOLVED_DIR/$(basename "$FILE_PATH")"
        _WC_RESOLVED_ROOT="$(realpath "$PROJECT_ROOT" 2>/dev/null || echo "$PROJECT_ROOT")"
        _WC_REL="${_WC_RESOLVED_FILE#$_WC_RESOLVED_ROOT/}"
        if [[ "$_WC_REL" == "$_WC_RESOLVED_FILE" ]]; then
            _WC_REL="${FILE_PATH#$_WC_RESOLVED_ROOT/}"
            if [[ "$_WC_REL" == "$FILE_PATH" ]]; then
                _WC_REL="${FILE_PATH#$PROJECT_ROOT/}"
            fi
        fi

        # Only enforce for files inside the project root
        if [[ "$_WC_REL" != "$FILE_PATH" ]]; then
            _WC_EXEMPT=false
            case "$_WC_REL" in
                .claude/plans/*)        _WC_EXEMPT=true ;;
                .claude/logs/*)         _WC_EXEMPT=true ;;
                .claude/pending-actions.json) _WC_EXEMPT=true ;;
                .claude/learnings.md)   _WC_EXEMPT=true ;;
                .claude/.update-cache/*) _WC_EXEMPT=true ;;
            esac

            if [ "$_WC_EXEMPT" = "false" ]; then
                echo "BLOCKED: Write to repo file outside of a worktree" >&2
                echo "" >&2
                echo "  File: $_WC_REL" >&2
                echo "" >&2
                echo "  Sessions that write code MUST use a worktree for isolation." >&2
                echo "  Run /worktree-start or call EnterWorktree() first." >&2
                echo "" >&2
                echo "  If this is a one-off edit that genuinely doesn't need isolation:" >&2
                echo "    CLAUDE_ALLOW_MAIN_WRITE=true <your command>" >&2
                echo "" >&2
                exit 2
            fi
        fi
    fi
else
    _log_bypass "CLAUDE_ALLOW_MAIN_WRITE" "1" "worktree isolation bypassed for: ${FILE_PATH##*/}"
fi

# ============================================
# LEARNINGS ARCHIVAL GUARD
# ============================================
# Blocks bulk truncation of learnings.md without a recent archive update.
# Prevents the doc-flywheel Step 3 archival step from being skipped.
# Bypass: SKIP_LEARNINGS_GUARD=true

if [[ "$SKIP_LEARNINGS_GUARD" = "true" ]] && [[ "$FILE_PATH" =~ learnings\.md$ ]]; then
    _log_bypass "SKIP_LEARNINGS_GUARD" "2" "learnings archival guard bypassed"
fi
if [[ "$SKIP_LEARNINGS_GUARD" != "true" ]] && \
   [[ "$FILE_PATH" =~ learnings\.md$ ]] && \
   [[ ! "$FILE_PATH" =~ learnings-archive\.md$ ]]; then
    # Resolve the actual file (may be behind a symlink)
    _LEARNINGS_DIR="$(dirname "$FILE_PATH")"
    _LEARNINGS_REAL_DIR="$(realpath "$_LEARNINGS_DIR" 2>/dev/null || echo "$_LEARNINGS_DIR")"
    _LEARNINGS_REAL="$_LEARNINGS_REAL_DIR/$(basename "$FILE_PATH")"
    if [ -f "$_LEARNINGS_REAL" ]; then
        _CURRENT_LINES=$(wc -l < "$_LEARNINGS_REAL" | tr -d ' ')
        # Compute expected line count after this operation
        if [ -n "$OLD_STRING" ]; then
            # Edit operation: expected = current - removed + added
            _OLD_LINES=$(printf '%s' "$OLD_STRING" | wc -l | tr -d ' ')
            if [ -n "$CONTENT" ]; then
                _ADD_LINES=$(printf '%s' "$CONTENT" | wc -l | tr -d ' ')
            else
                _ADD_LINES=0
            fi
            _NEW_LINES=$(( _CURRENT_LINES - _OLD_LINES + _ADD_LINES ))
            [ "$_NEW_LINES" -lt 0 ] && _NEW_LINES=0
        else
            # Write operation: CONTENT is the full replacement file
            _NEW_LINES=$(printf '%s' "$CONTENT" | wc -l | tr -d ' ')
        fi
        # Trigger: file >100 lines being reduced to <50% of current size
        if [ "$_CURRENT_LINES" -gt 100 ] && [ "$_NEW_LINES" -lt $(( _CURRENT_LINES / 2 )) ]; then
            _ARCHIVE_REAL="$_LEARNINGS_REAL_DIR/learnings-archive.md"
            _ARCHIVE_FRESH=false
            if [ -f "$_ARCHIVE_REAL" ]; then
                _ARCHIVE_MTIME=$(stat -f %m "$_ARCHIVE_REAL" 2>/dev/null || stat -c %Y "$_ARCHIVE_REAL" 2>/dev/null || echo 0)
                _NOW=$(date +%s)
                # Archive must have been modified within last 5 minutes
                if [ $(( _NOW - _ARCHIVE_MTIME )) -lt 300 ]; then
                    _ARCHIVE_FRESH=true
                fi
            fi
            if [ "$_ARCHIVE_FRESH" = "false" ]; then
                echo "BLOCKED: learnings.md is being reduced from $_CURRENT_LINES to $_NEW_LINES lines" >&2
                echo "without a recent update to learnings-archive.md." >&2
                echo "" >&2
                echo "Per doc-flywheel Step 3: ALWAYS copy entries to learnings-archive.md" >&2
                echo "before clearing them from learnings.md." >&2
                echo "" >&2
                echo "To fix: append entries to learnings-archive.md first, then clear." >&2
                echo "Override: SKIP_LEARNINGS_GUARD=true" >&2
                exit 2
            fi
        fi
    fi
fi

# ============================================
# RESOLVE PATHS FOR DOWNSTREAM CHECKS
# ============================================
# Resolve symlinks once for all downstream sections.
# FILE_PATH is guaranteed absolute (CC v2.1.88+) but not symlink-resolved.
# macOS: /tmp → /private/tmp still requires realpath resolution.
# For new files (pre-write), realpath fails on the file itself because it
# doesn't exist yet. Resolve the directory portion instead, then reattach
# the filename.
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
_FILE_DIR="$(dirname "$FILE_PATH")"
_RESOLVED_DIR="$(realpath "$_FILE_DIR" 2>/dev/null || echo "$_FILE_DIR")"
RESOLVED_FILE_PATH="$_RESOLVED_DIR/$(basename "$FILE_PATH")"
RESOLVED_PROJECT_ROOT="$(realpath "$PROJECT_ROOT" 2>/dev/null || echo "$PROJECT_ROOT")"

# ============================================
# CREDENTIAL SAFETY CHECK
# ============================================

# Skip credential checks for infrastructure/config files that legitimately
# contain credentials, plus test files, docs, and env examples.
# Uses a flag instead of exit 0 so downstream checks (assertion warnings,
# naming patterns) still run — those are specifically designed for .md files.
SKIP_CREDENTIALS=false

# Test files and docs
if [[ "$FILE_PATH" =~ \.test\.(js|ts)$ ]] || [[ "$FILE_PATH" =~ \.spec\.(js|ts)$ ]] || \
   [[ "$FILE_PATH" =~ _test\.go$ ]] || \
   [[ "$FILE_PATH" =~ __tests__/ ]] || [[ "$FILE_PATH" =~ \.md$ ]] || \
   [[ "$FILE_PATH" =~ \.env\.example$ ]] || [[ "$FILE_PATH" =~ \.env\.sample$ ]]; then
    SKIP_CREDENTIALS=true
fi

# Infrastructure/config files that legitimately contain credentials.
# These are gitignored or external to the repo — not application code.
if [[ "$(basename "$FILE_PATH")" =~ ^\.env(\..*)?$ ]] || \
   [[ "$FILE_PATH" =~ \.twilio-cli/ ]] || \
   [[ "$FILE_PATH" =~ node_modules/ ]]; then
    SKIP_CREDENTIALS=true
fi

if [ "$SKIP_CREDENTIALS" = "false" ]; then
    # Pattern for Twilio Account SID (not in env var reference)
    if echo "$CONTENT" | grep -E "AC[a-f0-9]{32}" | grep -vqE "(process\.env|context\.|TWILIO_ACCOUNT_SID|ACCOUNT_SID)"; then
        echo "BLOCKED: Hardcoded Twilio Account SID detected!" >&2
        echo "" >&2
        echo "Found pattern matching 'ACxxxxxxxx...' which appears to be a hardcoded Account SID." >&2
        echo "Use environment variables instead:" >&2
        echo "  - In serverless functions: context.TWILIO_ACCOUNT_SID" >&2
        echo "  - In Node.js: process.env.TWILIO_ACCOUNT_SID" >&2
        echo "" >&2
        exit 2
    fi

    # Pattern for Twilio API Key SID
    if echo "$CONTENT" | grep -E "SK[a-f0-9]{32}" | grep -vqE "(process\.env|context\.|TWILIO_API_KEY|API_KEY)"; then
        echo "BLOCKED: Hardcoded Twilio API Key SID detected!" >&2
        echo "" >&2
        echo "API Keys must not be hardcoded. Use environment variables:" >&2
        echo "  - context.TWILIO_API_KEY or process.env.TWILIO_API_KEY" >&2
        echo "" >&2
        exit 2
    fi

    # Pattern for hardcoded auth token assignment
    if echo "$CONTENT" | grep -qE "(authToken|AUTH_TOKEN)['\"]?\s*[:=]\s*['\"][a-f0-9]{32}['\"]"; then
        echo "BLOCKED: Hardcoded Twilio Auth Token detected!" >&2
        echo "" >&2
        echo "Auth tokens must never be hardcoded. Use environment variables:" >&2
        echo "  - In serverless functions: context.TWILIO_AUTH_TOKEN" >&2
        echo "  - In Node.js: process.env.TWILIO_AUTH_TOKEN" >&2
        echo "" >&2
        exit 2
    fi
fi

# ============================================
# MARKDOWN CREDENTIAL CHECK
# ============================================
# .md files are exempt from SID checks (AC.../SK... appear in format docs),
# but we still catch ACTUAL credential values — 32-char hex strings
# directly assigned to credential keywords. This catches real tokens
# leaked into test-results.md or similar documentation files.
# Pattern: keyword followed by separator then a quoted 32-char hex value
# e.g., auth_token: "ff5711..." or secret = "abc123..."

if [[ "$FILE_PATH" =~ \.md$ ]] && [ -n "$CONTENT" ]; then
    if echo "$CONTENT" | grep -qiE '(auth_token|_secret|password|authtoken)["'"'"'"]?[[:space:]]*[:=][[:space:]]*["'"'"'"][a-f0-9]{32}["'"'"'"]'; then
        echo "BLOCKED: Possible credential value in markdown file!" >&2
        echo "" >&2
        echo "Found a 32-character hex string adjacent to a credential keyword" >&2
        echo "in: $FILE_PATH" >&2
        echo "" >&2
        echo "If this is a real credential, replace it with [REDACTED] or a placeholder." >&2
        echo "If this is a format example, use a clearly fake value like:" >&2
        echo "  a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4" >&2
        echo "" >&2
        exit 2
    fi
fi

# ============================================
# PROMPT INJECTION HEURISTIC CHECK
# ============================================

# Skip injection checks for documentation files (they legitimately discuss these topics)
SKIP_INJECTION=false
if [[ "$FILE_PATH" =~ \.md$ ]] || [[ "$FILE_PATH" =~ CLAUDE\.md$ ]] || \
   [[ "$FILE_PATH" =~ \.test\.(js|ts)$ ]] || [[ "$FILE_PATH" =~ __tests__/ ]] || \
   [[ "$FILE_PATH" =~ _safety-patterns\.sh$ ]]; then
    SKIP_INJECTION=true
fi

if [ "$SKIP_INJECTION" = "false" ] && [ -n "$CONTENT" ]; then
    source "$HOOK_DIR/_emit-event.sh"
    source "$HOOK_DIR/_safety-patterns.sh"
    EMIT_SESSION_ID="$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null)"

    if ! check_injection_patterns "$CONTENT" "file_content"; then
        echo "BLOCKED: Content contains text matching known prompt injection patterns." >&2
        echo "" >&2
        echo "This may be a false positive. If the content is legitimate:" >&2
        echo "  - Documentation files (.md) are exempt from this check" >&2
        echo "  - Test files are exempt from this check" >&2
        echo "  - Review the content and use Bash write if needed" >&2
        echo "" >&2
        exit 2
    fi
fi

# ============================================
# ABOUTME VALIDATION FOR NEW JS FILES
# ============================================

# Check if this is a new JavaScript function file (not a test)
# Use both raw and resolved paths to handle macOS /tmp → /private/tmp symlinks
if { [[ "$FILE_PATH" =~ functions/.*\.js$ ]] || [[ "$RESOLVED_FILE_PATH" =~ functions/.*\.js$ ]]; } && \
   [[ ! "$FILE_PATH" =~ \.test\.js$ ]]; then
    # Check if file doesn't exist yet (new file) — check both path forms
    if [ ! -f "$FILE_PATH" ] && [ ! -f "$RESOLVED_FILE_PATH" ]; then
        # Validate ABOUTME is present in content being written
        if ! echo "$CONTENT" | head -5 | grep -q "// ABOUTME:"; then
            echo "BLOCKED: New function file missing ABOUTME comment!" >&2
            echo "" >&2
            echo "All code files must start with a 2-line ABOUTME comment:" >&2
            echo "" >&2
            echo "// ABOUTME: [What this file does - action-oriented]" >&2
            echo "// ABOUTME: [Additional context - key behaviors, dependencies]" >&2
            echo "" >&2
            echo "Example:" >&2
            echo "// ABOUTME: Handles incoming voice calls with greeting and input gathering." >&2
            echo "// ABOUTME: Uses Polly.Amy voice and supports DTMF and speech input." >&2
            echo "" >&2
            exit 2
        fi
    fi
fi

# ============================================
# PIPELINE GATE — New functions require tests
# ============================================

# Only check new function files (not tests, not helpers/private utilities)
if { [[ "$FILE_PATH" =~ functions/.*\.js$ ]] || [[ "$RESOLVED_FILE_PATH" =~ functions/.*\.js$ ]]; } && \
   [[ ! "$FILE_PATH" =~ \.test\.js$ ]] && \
   [[ ! "$FILE_PATH" =~ _test\.go$ ]] && \
   [[ ! "$FILE_PATH" =~ /helpers/ ]]; then

    if [ ! -f "$FILE_PATH" ] && [ ! -f "$RESOLVED_FILE_PATH" ]; then
        # Skip if override is set
        if [ "${SKIP_PIPELINE_GATE:-}" = "true" ]; then
            echo "Pipeline gate bypassed (SKIP_PIPELINE_GATE=true)" >&2
            _log_bypass "SKIP_PIPELINE_GATE" "1" "TDD pipeline gate bypassed for: ${FILE_PATH##*/}"
        else
            # Derive expected test path
            # functions/voice/ivr-welcome.js → __tests__/unit/voice/ivr-welcome.test.js
            # functions/voice/ivr-welcome.protected.js → __tests__/unit/voice/ivr-welcome.test.js
            REL_FUNC="${FILE_PATH#*/functions/}"
            DOMAIN=$(dirname "$REL_FUNC")
            BASENAME=$(basename "$REL_FUNC" .js)
            BASENAME="${BASENAME%.protected}"
            BASENAME="${BASENAME%.private}"
            TEST_PATH="__tests__/unit/${DOMAIN}/${BASENAME}.test.js"

            if [ ! -f "$PROJECT_ROOT/$TEST_PATH" ] && [ ! -f "$RESOLVED_PROJECT_ROOT/$TEST_PATH" ]; then
                echo "" >&2
                echo "BLOCKED: New function file has no corresponding tests!" >&2
                echo "" >&2
                echo "  Function:  functions/${REL_FUNC}" >&2
                echo "  Expected:  ${TEST_PATH}" >&2
                echo "" >&2
                echo "This project enforces pipeline-driven development." >&2
                echo "For new features, use the development pipeline:" >&2
                echo "" >&2
                echo "  /architect [feature]   # Start with design review" >&2
                echo "  /test-gen [feature]    # Write failing tests first" >&2
                echo "  /dev [task]            # Then implement" >&2
                echo "" >&2
                echo "See .claude/references/workflow-patterns.md for full phase sequences." >&2
                echo "" >&2
                echo "Override: SKIP_PIPELINE_GATE=true (for emergency fixes)" >&2
                exit 2
            fi
        fi
    fi
fi

# ============================================
# TEST FILE ABOUTME WARNING (not blocking)
# ============================================

if [[ "$FILE_PATH" =~ \.test\.js$ ]] || [[ "$FILE_PATH" =~ __tests__ ]]; then
    if [ ! -f "$FILE_PATH" ]; then
        if ! echo "$CONTENT" | head -5 | grep -q "// ABOUTME:"; then
            echo "Note: Consider adding ABOUTME comment to test file." >&2
        fi
    fi
fi

# ============================================
# HIGH-RISK ASSERTION WARNING (not blocking)
# ============================================

# Check documentation files for high-risk assertion patterns
if [[ "$FILE_PATH" =~ CLAUDE\.md$ ]] || [[ "$FILE_PATH" =~ \.claude/skills/.*\.md$ ]]; then
    WARNED=false

    # Check for negative behavioral claims without citation
    if echo "$CONTENT" | grep -qiE "(cannot|can't|not able to|impossible|not supported|not available)" && \
       ! echo "$CONTENT" | grep -qE "<!-- (verified|UNVERIFIED):"; then
        if [ "$WARNED" = false ]; then
            echo "" >&2
            echo "⚠️  HIGH-RISK ASSERTION WARNING" >&2
            echo "   File: $FILE_PATH" >&2
            WARNED=true
        fi
        echo "   → Negative behavioral claim detected (cannot/not supported/etc.)" >&2
    fi

    # Check for absolute claims without citation
    if echo "$CONTENT" | grep -qE "\b(always|never|must|only)\b" && \
       echo "$CONTENT" | grep -qiE "(twilio|twiml|api|webhook|call|sms|message)" && \
       ! echo "$CONTENT" | grep -qE "<!-- (verified|UNVERIFIED):"; then
        if [ "$WARNED" = false ]; then
            echo "" >&2
            echo "⚠️  HIGH-RISK ASSERTION WARNING" >&2
            echo "   File: $FILE_PATH" >&2
            WARNED=true
        fi
        echo "   → Absolute claim detected (always/never/must/only)" >&2
    fi

    # Check for numeric limits without citation (e.g., "max 16KB", "up to 4")
    if echo "$CONTENT" | grep -qE "(max|maximum|up to|at least|limit)[^a-z]*[0-9]+" && \
       ! echo "$CONTENT" | grep -qE "<!-- (verified|UNVERIFIED):"; then
        if [ "$WARNED" = false ]; then
            echo "" >&2
            echo "⚠️  HIGH-RISK ASSERTION WARNING" >&2
            echo "   File: $FILE_PATH" >&2
            WARNED=true
        fi
        echo "   → Numeric limit detected without citation" >&2
    fi

    if [ "$WARNED" = true ]; then
        echo "" >&2
        echo "   Did you verify these claims against official Twilio docs?" >&2
        echo "   Add citations: <!-- verified: twilio.com/docs/... -->" >&2
        echo "   Or mark uncertain: <!-- UNVERIFIED: reason -->" >&2
        echo "" >&2
    fi
fi

# ============================================
# NON-EVERGREEN NAMING PATTERN WARNING (not blocking)
# ============================================

# Check for naming patterns that indicate temporal context
# These names will become misleading as codebase evolves
if echo "$CONTENT" | grep -qE "\b(Improved|Enhanced|Better|Refactored)[A-Z][a-zA-Z]*"; then
    MATCHED_NAMES=$(echo "$CONTENT" | grep -oE "\b(Improved|Enhanced|Better|Refactored)[A-Z][a-zA-Z]*" | head -5 | tr '\n' ', ' | sed 's/,$//')
    echo "" >&2
    echo "⚠️  NON-EVERGREEN NAMING WARNING" >&2
    echo "   File: $FILE_PATH" >&2
    echo "   Found: $MATCHED_NAMES" >&2
    echo "" >&2
    echo "   Names like 'ImprovedX' or 'BetterY' become misleading over time." >&2
    echo "   What's 'improved' today will be 'old' tomorrow." >&2
    echo "   Use descriptive names that explain WHAT it does, not WHEN it was written." >&2
    echo "" >&2
fi

# Also check for "New" prefix followed by uppercase (but allow "new" in sentences)
# Pattern: NewSomething in declarations (not "new something" or "newline")
if echo "$CONTENT" | grep -qE "(const|let|var|function|class|type|interface)\s+New[A-Z]"; then
    MATCHED_NAMES=$(echo "$CONTENT" | grep -oE "(const|let|var|function|class|type|interface)\s+New[A-Z][a-zA-Z]*" | sed 's/^[a-z]* //' | head -5 | tr '\n' ', ' | sed 's/,$//')
    echo "" >&2
    echo "⚠️  NON-EVERGREEN NAMING WARNING" >&2
    echo "   File: $FILE_PATH" >&2
    echo "   Found: $MATCHED_NAMES" >&2
    echo "" >&2
    echo "   Names like 'NewHandler' will be outdated when you add another one." >&2
    echo "   Use descriptive names instead: 'StreamingHandler', 'BatchHandler', etc." >&2
    echo "" >&2
fi

# ============================================
# MAGIC TEST NUMBER CHECK (BLOCKING)
# ============================================

# Twilio magic test numbers (+15005550xxx) should only be in test files
# These are special numbers that bypass actual phone networks
if echo "$CONTENT" | grep -qE "\+?1?5005550[0-9]{3}"; then
    # Check if this is a test file
    if [[ ! "$FILE_PATH" =~ (\.test\.|\.spec\.|__tests__|test/|tests/|\.test$|\.spec$) ]]; then
        MATCHED_NUMBERS=$(echo "$CONTENT" | grep -oE "\+?1?5005550[0-9]{3}" | head -3 | tr '\n' ', ' | sed 's/,$//')
        echo "BLOCKED: Twilio magic test numbers in non-test file!" >&2
        echo "" >&2
        echo "Found: $MATCHED_NUMBERS" >&2
        echo "File: $FILE_PATH" >&2
        echo "" >&2
        echo "Magic test numbers (+15005550xxx) bypass actual phone networks and" >&2
        echo "should only be used in test files." >&2
        echo "" >&2
        echo "For test files: rename to .test.js/.spec.js or move to __tests__/" >&2
        echo "For production: use environment variables for phone numbers" >&2
        echo "" >&2
        exit 2
    fi
fi

exit 0
