#!/bin/bash
# ABOUTME: Session-end checklist hook that warns about uncommitted or unpushed work.
# ABOUTME: Runs on Stop event to prevent losing work at the end of a session.

# ============================================
# UNCOMMITTED CHANGES CHECK
# ============================================

if [ -d ".git" ]; then
    UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$UNCOMMITTED" -gt 0 ]; then
        echo "" >&2
        echo "Session ending with $UNCOMMITTED uncommitted change(s)." >&2
        echo "Consider committing your work before ending the session." >&2
        echo "" >&2
    fi

    # ============================================
    # UNPUSHED COMMITS CHECK
    # ============================================

    UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
    if [ -n "$UPSTREAM" ]; then
        UNPUSHED=$(git log --oneline "$UPSTREAM"..HEAD 2>/dev/null | wc -l | tr -d ' ')
        if [ "$UNPUSHED" -gt 0 ]; then
            echo "You have $UNPUSHED unpushed commit(s)." >&2
            echo "" >&2
        fi
    else
        # No upstream - check if there are any commits on this branch
        COMMITS=$(git log --oneline -1 2>/dev/null | wc -l | tr -d ' ')
        if [ "$COMMITS" -gt 0 ]; then
            BRANCH=$(git branch --show-current 2>/dev/null)
            if [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ]; then
                echo "Branch '$BRANCH' has no remote tracking. Consider pushing." >&2
                echo "" >&2
            fi
        fi
    fi
fi

exit 0
