#!/bin/bash
# ABOUTME: Checks all package.json files for outdated dependencies within semver ranges.
# ABOUTME: Categorizes bumps as safe (patch/minor within range) vs breaking (major version jump).

set -uo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_DIR="$PROJECT_ROOT/.claude/.update-cache"
CACHE_FILE="$CACHE_DIR/deps-state.json"
DIGEST_FILE="$CACHE_DIR/deps-digest.md"
CACHE_TTL_SECONDS=604800  # 7 days

# --- Flags ---
QUIET=false
FORCE=false
JSON_OUTPUT=false
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=true ;;
        --force) FORCE=true ;;
        --json) JSON_OUTPUT=true ;;
        --help)
            echo "Usage: check-deps.sh [--quiet] [--force] [--json]"
            echo ""
            echo "  --quiet   Only output if safe bumps are available"
            echo "  --force   Bypass cache and check npm registry now"
            echo "  --json    Output raw JSON instead of formatted report"
            echo ""
            echo "Checks all package.json files for outdated dependencies."
            echo "Categorizes into safe (within semver range) vs breaking (major bump)."
            exit 0
            ;;
    esac
done

# --- Helpers ---
log() {
    if [ "$QUIET" = false ]; then
        echo "$@" >&2
    fi
}

# --- Require tools ---
if ! command -v jq >/dev/null 2>&1; then
    log "check-deps: jq not found, skipping"
    exit 0
fi

if ! command -v npm >/dev/null 2>&1; then
    log "check-deps: npm not found, skipping"
    exit 0
fi

# --- Cache check ---
use_cache() {
    if [ "$FORCE" = true ]; then return 1; fi
    if [ ! -f "$CACHE_FILE" ]; then return 1; fi
    local cache_ts
    cache_ts=$(jq -r '.checked_at // 0' "$CACHE_FILE" 2>/dev/null)
    local now; now=$(date +%s)
    local age=$(( now - cache_ts ))
    [ "$age" -lt "$CACHE_TTL_SECONDS" ]
}

# --- Check cache freshness ---
if use_cache; then
    SAFE_COUNT=$(jq -r '.total_safe // 0' "$CACHE_FILE" 2>/dev/null)
    BREAKING_COUNT=$(jq -r '.total_breaking // 0' "$CACHE_FILE" 2>/dev/null)
    if [ "$SAFE_COUNT" -gt 0 ]; then
        echo "DEPS: $SAFE_COUNT safe bump(s) available, $BREAKING_COUNT major upgrade(s) deferred. Run /check-deps to review." >&2
    fi
    if [ "$QUIET" = false ] && [ -f "$DIGEST_FILE" ]; then
        cat "$DIGEST_FILE"
    fi
    exit 0
fi

# --- Discover package directories ---
PACKAGE_DIRS=()
while IFS= read -r pkg; do
    PACKAGE_DIRS+=("$(dirname "$pkg")")
done < <(find "$PROJECT_ROOT" -name package.json -not -path "*/node_modules/*" -not -path "*/.meta/*" | sort)

log "Checking ${#PACKAGE_DIRS[@]} package directories..."

# --- Collect outdated deps ---
ALL_SAFE=()
ALL_BREAKING=()
TOTAL_SAFE=0
TOTAL_BREAKING=0

for PKG_DIR in "${PACKAGE_DIRS[@]}"; do
    REL_DIR="${PKG_DIR#"$PROJECT_ROOT/"}"
    if [ "$REL_DIR" = "$PROJECT_ROOT" ]; then
        REL_DIR="(root)"
    fi

    # Skip dirs without node_modules (uninstalled)
    if [ ! -d "$PKG_DIR/node_modules" ]; then
        log "  $REL_DIR: skipped (no node_modules)"
        continue
    fi

    OUTDATED_JSON=$(cd "$PKG_DIR" && npm outdated --json 2>/dev/null) || true

    if [ -z "$OUTDATED_JSON" ] || [ "$OUTDATED_JSON" = "{}" ]; then
        log "  $REL_DIR: all up to date"
        continue
    fi

    # Parse each outdated package
    PACKAGES=$(echo "$OUTDATED_JSON" | jq -r 'keys[]' 2>/dev/null)
    for PKG_NAME in $PACKAGES; do
        CURRENT=$(echo "$OUTDATED_JSON" | jq -r ".\"$PKG_NAME\".current // \"?\"")
        WANTED=$(echo "$OUTDATED_JSON" | jq -r ".\"$PKG_NAME\".wanted // \"?\"")
        LATEST=$(echo "$OUTDATED_JSON" | jq -r ".\"$PKG_NAME\".latest // \"?\"")

        # Determine if this is a safe bump (wanted > current) or breaking (latest > wanted)
        if [ "$CURRENT" = "?" ] || [ "$WANTED" = "?" ]; then
            continue
        fi

        if [ "$CURRENT" != "$WANTED" ]; then
            ALL_SAFE+=("$PKG_NAME|$CURRENT|$WANTED|$REL_DIR")
            TOTAL_SAFE=$((TOTAL_SAFE + 1))
        fi

        if [ "$WANTED" != "$LATEST" ]; then
            # Extract major versions to confirm it's a major bump
            WANTED_MAJOR=$(echo "$WANTED" | cut -d. -f1)
            LATEST_MAJOR=$(echo "$LATEST" | cut -d. -f1)
            if [ "$WANTED_MAJOR" != "$LATEST_MAJOR" ]; then
                ALL_BREAKING+=("$PKG_NAME|$WANTED|$LATEST|$REL_DIR")
                TOTAL_BREAKING=$((TOTAL_BREAKING + 1))
            fi
        fi
    done
done

# --- Deduplicate using temp files (bash 3.x compat, no associative arrays) ---
SAFE_TMP=$(mktemp)
BREAKING_TMP=$(mktemp)
trap 'rm -f "$SAFE_TMP" "$BREAKING_TMP"' EXIT

for entry in "${ALL_SAFE[@]+"${ALL_SAFE[@]}"}"; do
    [ -z "$entry" ] && continue
    echo "$entry" >> "$SAFE_TMP"
done

for entry in "${ALL_BREAKING[@]+"${ALL_BREAKING[@]}"}"; do
    [ -z "$entry" ] && continue
    echo "$entry" >> "$BREAKING_TMP"
done

# Group by name|current|wanted, merge dirs with awk
# Input: name|current|wanted|dir  Output: name|current|wanted|dir1, dir2
dedup_entries() {
    sort -t'|' -k1,3 "$1" | awk -F'|' '
    {
        key = $1 "|" $2 "|" $3
        if (key == prev_key) {
            dirs = dirs ", " $4
        } else {
            if (NR > 1) print prev_key "|" dirs
            prev_key = key
            dirs = $4
        }
    }
    END { if (NR > 0) print prev_key "|" dirs }
    '
}

# Deduplicated counts (unique package+version combos)
SAFE_DEDUP_COUNT=0
if [ -s "$SAFE_TMP" ]; then
    SAFE_DEDUP_COUNT=$(dedup_entries "$SAFE_TMP" | wc -l | tr -d ' ')
fi
BREAKING_DEDUP_COUNT=0
if [ -s "$BREAKING_TMP" ]; then
    BREAKING_DEDUP_COUNT=$(dedup_entries "$BREAKING_TMP" | wc -l | tr -d ' ')
fi

# --- JSON output mode ---
if [ "$JSON_OUTPUT" = true ]; then
    SAFE_JSON="["
    FIRST=true
    if [ -s "$SAFE_TMP" ]; then
        while IFS='|' read -r name current wanted dirs; do
            if [ "$FIRST" = true ]; then FIRST=false; else SAFE_JSON="$SAFE_JSON,"; fi
            SAFE_JSON="$SAFE_JSON{\"name\":\"$name\",\"current\":\"$current\",\"wanted\":\"$wanted\",\"dirs\":\"$dirs\"}"
        done < <(dedup_entries "$SAFE_TMP")
    fi
    SAFE_JSON="$SAFE_JSON]"

    BREAKING_JSON="["
    FIRST=true
    if [ -s "$BREAKING_TMP" ]; then
        while IFS='|' read -r name wanted latest dirs; do
            if [ "$FIRST" = true ]; then FIRST=false; else BREAKING_JSON="$BREAKING_JSON,"; fi
            BREAKING_JSON="$BREAKING_JSON{\"name\":\"$name\",\"wanted\":\"$wanted\",\"latest\":\"$latest\",\"dirs\":\"$dirs\"}"
        done < <(dedup_entries "$BREAKING_TMP")
    fi
    BREAKING_JSON="$BREAKING_JSON]"

    echo "{\"safe\":$SAFE_JSON,\"breaking\":$BREAKING_JSON,\"total_safe\":$TOTAL_SAFE,\"total_breaking\":$TOTAL_BREAKING}"
    exit 0
fi

# --- Write digest ---
NOW_ISO=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)
mkdir -p "$CACHE_DIR"

{
    echo "# Dependency Check — $NOW_ISO"
    echo ""

    if [ "$TOTAL_SAFE" -gt 0 ]; then
        echo "## Safe Bumps ($TOTAL_SAFE total, $SAFE_DEDUP_COUNT unique)"
        echo ""
        echo "Within declared semver ranges. Apply with \`npm update\` in each directory."
        echo ""
        echo "| Package | Current | Target | Location(s) |"
        echo "|---------|---------|--------|-------------|"
        if [ -s "$SAFE_TMP" ]; then
            dedup_entries "$SAFE_TMP" | while IFS='|' read -r name current wanted dirs; do
                echo "| \`$name\` | $current | $wanted | $dirs |"
            done
        fi
        echo ""
    fi

    if [ "$TOTAL_BREAKING" -gt 0 ]; then
        echo "## Major Upgrades Deferred ($TOTAL_BREAKING total, $BREAKING_DEDUP_COUNT unique)"
        echo ""
        echo "Require manual migration. Review changelogs before bumping."
        echo ""
        echo "| Package | Current | Latest | Location(s) |"
        echo "|---------|---------|--------|-------------|"
        if [ -s "$BREAKING_TMP" ]; then
            dedup_entries "$BREAKING_TMP" | while IFS='|' read -r name wanted latest dirs; do
                echo "| \`$name\` | $wanted | $latest | $dirs |"
            done
        fi
        echo ""
    fi

    if [ "$TOTAL_SAFE" -eq 0 ] && [ "$TOTAL_BREAKING" -eq 0 ]; then
        echo "All dependencies are up to date across ${#PACKAGE_DIRS[@]} packages."
        echo ""
    fi

    echo "---"
    echo "*Generated by check-deps.sh. Run \`/check-deps\` to review and apply.*"
} > "$DIGEST_FILE"

# --- Write state ---
cat > "$CACHE_FILE" <<STATEEOF
{
  "checked_at": $(date +%s),
  "total_safe": $TOTAL_SAFE,
  "total_breaking": $TOTAL_BREAKING,
  "package_count": ${#PACKAGE_DIRS[@]}
}
STATEEOF

# --- Output ---
if [ "$TOTAL_SAFE" -gt 0 ]; then
    echo "DEPS: $TOTAL_SAFE safe bump(s) available, $TOTAL_BREAKING major upgrade(s) deferred." >&2
fi

if [ "$QUIET" = false ]; then
    cat "$DIGEST_FILE"
fi

if [ "$TOTAL_SAFE" -eq 0 ] && [ "$TOTAL_BREAKING" -eq 0 ]; then
    log "All dependencies up to date."
fi

exit 0
