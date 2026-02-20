#!/bin/bash
# ABOUTME: Post-write hook for auto-linting JavaScript files.
# ABOUTME: Runs ESLint with auto-fix after Write/Edit operations on JS files.

# Claude Code passes tool input as JSON on stdin, not env vars.
HOOK_INPUT=""
if [ ! -t 0 ]; then
    HOOK_INPUT="$(cat)"
fi

FILE_PATH=""
if [ -n "$HOOK_INPUT" ] && command -v jq &> /dev/null; then
    FILE_PATH="$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
fi

# Exit early if no file path
if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Only process JavaScript files
if [[ ! "$FILE_PATH" =~ \.(js|mjs|cjs)$ ]]; then
    exit 0
fi

# Skip node_modules and other excluded paths
if [[ "$FILE_PATH" =~ node_modules|\.min\.js|dist/|build/ ]]; then
    exit 0
fi

# Run ESLint with auto-fix if file exists
if [ -f "$FILE_PATH" ]; then
    if command -v npx &> /dev/null; then
        LINT_OUTPUT=$(npx eslint "$FILE_PATH" --fix 2>&1)
        LINT_EXIT=$?
        if [ $LINT_EXIT -ne 0 ] && [ -n "$LINT_OUTPUT" ]; then
            echo "ESLint found issues in $(basename "$FILE_PATH"):"
            echo "$LINT_OUTPUT" | head -20
        fi
    fi

    # Warn if ABOUTME is missing in function files (non-blocking)
    if [[ "$FILE_PATH" =~ functions/ ]] && [[ ! "$FILE_PATH" =~ \.test\.js$ ]]; then
        ABOUTME_COUNT=$(head -5 "$FILE_PATH" | grep -c "// ABOUTME:" || true)
        if [ "$ABOUTME_COUNT" -eq 0 ]; then
            echo ""
            echo "Note: $(basename "$FILE_PATH") is missing ABOUTME comment."
            echo "Consider adding at the top of the file:"
            echo "  // ABOUTME: [What this file does]"
            echo "  // ABOUTME: [Additional context]"
        elif [ "$ABOUTME_COUNT" -eq 1 ]; then
            echo ""
            echo "Note: $(basename "$FILE_PATH") has only 1 ABOUTME line (2 recommended)."
        fi
    fi
fi

exit 0
