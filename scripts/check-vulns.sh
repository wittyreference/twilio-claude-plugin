#!/bin/bash
# ABOUTME: Monitors all package-lock.json files for npm security vulnerabilities.
# ABOUTME: Tracks new vs known vulns, alerts on severity changes, 24h cache.

set -uo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_DIR="$PROJECT_ROOT/.claude/.update-cache"
STATE_FILE="$CACHE_DIR/vulns-state.json"
DIGEST_FILE="$CACHE_DIR/vulns-digest.md"
CACHE_TTL_SECONDS=86400  # 24 hours

# --- Flags ---
QUIET=false
FORCE=false
JSON_OUTPUT=false
ACK_ID=""
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=true ;;
        --force) FORCE=true ;;
        --json) JSON_OUTPUT=true ;;
        --acknowledge)
            # Next arg is the GHSA ID — handled below
            ;;
        --help)
            echo "Usage: check-vulns.sh [--quiet] [--force] [--json] [--acknowledge GHSA-ID]"
            echo ""
            echo "  --quiet              Only output if new vulnerabilities found"
            echo "  --force              Bypass cache and scan now"
            echo "  --json               Output raw JSON instead of formatted report"
            echo "  --acknowledge ID     Suppress alerts for a known vulnerability"
            echo ""
            echo "Scans all package-lock.json files for known npm vulnerabilities."
            echo "Uses npm audit (GitHub Advisory Database). 24h cache, session-start integrated."
            exit 0
            ;;
    esac
done

# Parse --acknowledge GHSA-ID (needs positional arg handling)
ARGS=("$@")
for i in "${!ARGS[@]}"; do
    if [ "${ARGS[$i]}" = "--acknowledge" ]; then
        ACK_ID="${ARGS[$((i + 1))]:-}"
        if [ -z "$ACK_ID" ]; then
            echo "Error: --acknowledge requires a GHSA ID (e.g., GHSA-3p68-rc4w-qgx5)" >&2
            exit 1
        fi
        break
    fi
done

# --- Helpers ---
log() {
    if [ "$QUIET" = false ]; then
        echo "$@" >&2
    fi
}

# Convert newline-separated strings to a JSON array, filtering empty lines
to_json_array() {
    local input="${1:-}"
    if [ -z "$input" ]; then
        echo "[]"
    else
        printf '%s\n' "$input" | jq -R -s 'split("\n") | map(select(length > 0))'
    fi
}

# --- Require tools ---
if ! command -v jq >/dev/null 2>&1; then
    log "check-vulns: jq not found, skipping"
    exit 0
fi

if ! command -v npm >/dev/null 2>&1; then
    log "check-vulns: npm not found, skipping"
    exit 0
fi

# --- Acknowledge mode ---
if [ -n "$ACK_ID" ]; then
    mkdir -p "$CACHE_DIR"
    if [ ! -f "$STATE_FILE" ]; then
        echo "No scan state found. Run check-vulns.sh --force first." >&2
        exit 1
    fi

    # Add to acknowledged array (deduplicated)
    UPDATED=$(jq --arg id "$ACK_ID" '
        .acknowledged = ((.acknowledged // []) + [$id] | unique)
    ' "$STATE_FILE")
    printf '%s\n' "$UPDATED" > "$STATE_FILE"
    echo "Acknowledged $ACK_ID. Will not trigger session-start alerts." >&2
    echo "Re-run with --force to regenerate digest." >&2
    exit 0
fi

# --- Cache check ---
use_cache() {
    if [ "$FORCE" = true ]; then return 1; fi
    if [ ! -f "$STATE_FILE" ]; then return 1; fi
    local cache_ts
    cache_ts=$(jq -r '.checked_at // 0' "$STATE_FILE" 2>/dev/null)
    local now; now=$(date +%s)
    local age=$(( now - cache_ts ))
    [ "$age" -lt "$CACHE_TTL_SECONDS" ]
}

# --- Check cache freshness ---
if use_cache; then
    # JSON mode: output state file as JSON
    if [ "$JSON_OUTPUT" = true ]; then
        cat "$STATE_FILE"
        exit 0
    fi

    # Emit one-liner from cached state if there are unacknowledged new vulns
    NEW_COUNT=$(jq -r '.new_count // 0' "$STATE_FILE" 2>/dev/null)
    TOTAL=$(jq -r '.total_vulns // 0' "$STATE_FILE" 2>/dev/null)
    CRITICAL=$(jq -r '.by_severity.critical // 0' "$STATE_FILE" 2>/dev/null)
    HIGH=$(jq -r '.by_severity.high // 0' "$STATE_FILE" 2>/dev/null)

    if [ "$NEW_COUNT" -gt 0 ]; then
        if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
            echo "VULNS: $NEW_COUNT new ($CRITICAL critical, $HIGH high). Run /check-vulns to review." >&2
        else
            echo "VULNS: $NEW_COUNT new vulnerability(ies). Run /check-vulns to review." >&2
        fi
    fi

    if [ "$QUIET" = false ] && [ -f "$DIGEST_FILE" ]; then
        cat "$DIGEST_FILE"
    fi
    exit 0
fi

# --- Discover package directories ---
PACKAGE_DIRS=()
while IFS= read -r lockfile; do
    PACKAGE_DIRS+=("$(dirname "$lockfile")")
done < <(find "$PROJECT_ROOT" -name package-lock.json -not -path "*/node_modules/*" -not -path "*/.meta/*" -not -path "$PROJECT_ROOT/.claude/worktrees/*" | sort)

log "Scanning ${#PACKAGE_DIRS[@]} packages for vulnerabilities..."

# --- Temp files for aggregation ---
ADVISORIES_TMP=$(mktemp)
VULNS_TMP=$(mktemp)
trap 'rm -f "$ADVISORIES_TMP" "$VULNS_TMP"' EXIT

PACKAGES_SCANNED=0
PACKAGES_SKIPPED=0

# --- Scan loop ---
for PKG_DIR in "${PACKAGE_DIRS[@]}"; do
    REL_DIR="${PKG_DIR#"$PROJECT_ROOT/"}"
    if [ "$REL_DIR" = "$PROJECT_ROOT" ]; then
        REL_DIR="(root)"
    fi

    # Skip dirs without node_modules
    if [ ! -d "$PKG_DIR/node_modules" ]; then
        log "  $REL_DIR: skipped (no node_modules)"
        PACKAGES_SKIPPED=$((PACKAGES_SKIPPED + 1))
        continue
    fi

    AUDIT_JSON=$(cd "$PKG_DIR" && npm audit --json 2>/dev/null) || true
    PACKAGES_SCANNED=$((PACKAGES_SCANNED + 1))

    if [ -z "$AUDIT_JSON" ]; then
        log "  $REL_DIR: audit failed"
        continue
    fi

    VULN_COUNT=$(echo "$AUDIT_JSON" | jq -r '.metadata.vulnerabilities.total // 0' 2>/dev/null)
    log "  $REL_DIR: $VULN_COUNT vulnerabilities"

    # Extract advisory objects (not string references)
    # Each via[] entry that is an object has: source, name, title, url, severity, cwe, range
    echo "$AUDIT_JSON" | jq -c --arg dir "$REL_DIR" '
        [.vulnerabilities | to_entries[].value | {
            pkg: .name,
            severity: .severity,
            isDirect: .isDirect,
            fixAvailable: .fixAvailable,
            via: [.via[] | select(type == "object")],
            dir: $dir
        } | select(.via | length > 0)][]
    ' 2>/dev/null >> "$VULNS_TMP"

    # Extract unique advisory metadata
    echo "$AUDIT_JSON" | jq -c --arg dir "$REL_DIR" '
        [.vulnerabilities | to_entries[].value.via[] |
         select(type == "object") |
         {id: .url, title: .title, severity: .severity, name: .name, range: .range, dir: $dir}][]
    ' 2>/dev/null >> "$ADVISORIES_TMP"
done

# --- Deduplicate advisories by URL (GHSA ID) ---
# Merge locations for the same advisory across packages
DEDUPED_JSON=$(jq -s '
    group_by(.id) |
    map({
        id: .[0].id,
        title: .[0].title,
        severity: .[0].severity,
        name: .[0].name,
        range: .[0].range,
        locations: [.[].dir] | unique
    }) |
    sort_by(
        if .severity == "critical" then 0
        elif .severity == "high" then 1
        elif .severity == "moderate" then 2
        elif .severity == "low" then 3
        else 4 end
    )
' "$ADVISORIES_TMP" 2>/dev/null)

# Extract all current advisory IDs
CURRENT_IDS=$(echo "$DEDUPED_JSON" | jq -r '.[].id // empty' 2>/dev/null | sort -u)

# Count by severity
TOTAL_VULNS=$(echo "$DEDUPED_JSON" | jq 'length' 2>/dev/null)
CRITICAL_COUNT=$(echo "$DEDUPED_JSON" | jq '[.[] | select(.severity == "critical")] | length' 2>/dev/null)
HIGH_COUNT=$(echo "$DEDUPED_JSON" | jq '[.[] | select(.severity == "high")] | length' 2>/dev/null)
MODERATE_COUNT=$(echo "$DEDUPED_JSON" | jq '[.[] | select(.severity == "moderate")] | length' 2>/dev/null)
LOW_COUNT=$(echo "$DEDUPED_JSON" | jq '[.[] | select(.severity == "low")] | length' 2>/dev/null)

# --- Diff against known state ---
KNOWN_IDS=""
ACKNOWLEDGED_IDS=""
IS_FIRST_RUN=false

if [ -f "$STATE_FILE" ]; then
    KNOWN_IDS=$(jq -r '.known_advisories[]? // empty' "$STATE_FILE" 2>/dev/null | sort -u)
    ACKNOWLEDGED_IDS=$(jq -r '.acknowledged[]? // empty' "$STATE_FILE" 2>/dev/null | sort -u)
else
    IS_FIRST_RUN=true
fi

# Compute new and resolved
NEW_IDS=""
RESOLVED_IDS=""
NEW_COUNT=0
RESOLVED_COUNT=0

# Helper: count non-empty lines in a variable
count_lines() {
    local text="$1"
    if [ -z "$text" ]; then echo 0; return; fi
    echo "$text" | grep -c . 2>/dev/null || echo 0
}

if [ "$IS_FIRST_RUN" = true ]; then
    NEW_COUNT=$TOTAL_VULNS
else
    NEW_IDS=$(comm -23 <(echo "$CURRENT_IDS") <(echo "$KNOWN_IDS") 2>/dev/null || true)
    RESOLVED_IDS=$(comm -23 <(echo "$KNOWN_IDS") <(echo "$CURRENT_IDS") 2>/dev/null || true)
    NEW_COUNT=$(count_lines "$NEW_IDS")
    RESOLVED_COUNT=$(count_lines "$RESOLVED_IDS")
fi

# Filter new IDs that are not acknowledged
UNACKED_NEW_COUNT=0
if [ "$NEW_COUNT" -gt 0 ] && [ -n "$ACKNOWLEDGED_IDS" ]; then
    UNACKED_NEW=$(comm -23 <(echo "$NEW_IDS" | sort) <(echo "$ACKNOWLEDGED_IDS" | sort) 2>/dev/null || true)
    UNACKED_NEW_COUNT=$(count_lines "$UNACKED_NEW")
else
    UNACKED_NEW_COUNT=$NEW_COUNT
fi

# Count acknowledged that are still present
ACK_STILL_PRESENT=0
if [ -n "$ACKNOWLEDGED_IDS" ]; then
    ACK_STILL_PRESENT_IDS=$(comm -12 <(echo "$CURRENT_IDS") <(echo "$ACKNOWLEDGED_IDS") 2>/dev/null || true)
    ACK_STILL_PRESENT=$(count_lines "$ACK_STILL_PRESENT_IDS")
fi

# Clean acknowledged list: remove IDs that no longer appear in current scan
CLEANED_ACK=""
if [ -n "$ACKNOWLEDGED_IDS" ]; then
    CLEANED_ACK=$(comm -12 <(echo "$CURRENT_IDS") <(echo "$ACKNOWLEDGED_IDS") 2>/dev/null || true)
fi

# --- Group fixes ---
FIX_GROUPS=$(jq -s '
    [.[] | select(.fixAvailable != null and .fixAvailable != false) |
     {fix_name: (if .fixAvailable | type == "object" then .fixAvailable.name else "npm audit fix" end),
      fix_version: (if .fixAvailable | type == "object" then .fixAvailable.version else null end),
      is_major: (if .fixAvailable | type == "object" then .fixAvailable.isSemVerMajor else false end),
      pkg: .pkg}] |
    group_by(.fix_name) |
    map({
        root_package: .[0].fix_name,
        fix_version: .[0].fix_version,
        is_major: .[0].is_major,
        vuln_count: length,
        affected: [.[].pkg] | unique
    }) |
    sort_by(-.vuln_count)
' "$VULNS_TMP" 2>/dev/null)

# --- JSON output mode ---
if [ "$JSON_OUTPUT" = true ]; then
    jq -nc \
        --arg scanned_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --argjson pkgs "$PACKAGES_SCANNED" \
        --argjson total "$TOTAL_VULNS" \
        --argjson critical "$CRITICAL_COUNT" \
        --argjson high "$HIGH_COUNT" \
        --argjson moderate "$MODERATE_COUNT" \
        --argjson low "$LOW_COUNT" \
        --argjson new_count "$NEW_COUNT" \
        --argjson resolved "$RESOLVED_COUNT" \
        --argjson advisories "$DEDUPED_JSON" \
        --argjson fix_groups "$FIX_GROUPS" \
        '{
            scanned_at: $scanned_at,
            packages_scanned: $pkgs,
            total_vulns: $total,
            by_severity: {critical: $critical, high: $high, moderate: $moderate, low: $low},
            new_count: $new_count,
            resolved_count: $resolved,
            advisories: $advisories,
            fix_groups: $fix_groups
        }'

    # Still update state even in JSON mode
    mkdir -p "$CACHE_DIR"
    jq -nc \
        --argjson ts "$(date +%s)" \
        --argjson total "$TOTAL_VULNS" \
        --argjson critical "$CRITICAL_COUNT" \
        --argjson high "$HIGH_COUNT" \
        --argjson moderate "$MODERATE_COUNT" \
        --argjson low "$LOW_COUNT" \
        --argjson new "$NEW_COUNT" \
        --argjson pkgs "$PACKAGES_SCANNED" \
        --argjson known "$(to_json_array "$CURRENT_IDS")" \
        --argjson ack "$(to_json_array "${CLEANED_ACK:-}")" \
        '{
            checked_at: $ts,
            total_vulns: $total,
            by_severity: {critical: $critical, high: $high, moderate: $moderate, low: $low},
            known_advisories: $known,
            acknowledged: $ack,
            packages_scanned: $pkgs,
            new_count: $new
        }' > "$STATE_FILE"
    exit 0
fi

# --- Write digest ---
NOW_ISO=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)
mkdir -p "$CACHE_DIR"

{
    echo "# Vulnerability Scan — $NOW_ISO"
    echo ""
    echo "**Scanned:** $PACKAGES_SCANNED packages ($PACKAGES_SKIPPED skipped — no node_modules)"
    echo "**Total:** $TOTAL_VULNS vulnerabilities ($CRITICAL_COUNT critical, $HIGH_COUNT high, $MODERATE_COUNT moderate, $LOW_COUNT low)"

    if [ "$IS_FIRST_RUN" = true ]; then
        echo "**Status:** Baseline scan (first run)"
    else
        echo "**New since last scan:** $NEW_COUNT"
        echo "**Resolved since last scan:** $RESOLVED_COUNT"
    fi

    if [ "$ACK_STILL_PRESENT" -gt 0 ]; then
        echo "**Acknowledged:** $ACK_STILL_PRESENT (suppressed from alerts)"
    fi
    echo ""

    # Emit tables by severity
    for SEV in critical high moderate low; do
        SEV_ITEMS=$(echo "$DEDUPED_JSON" | jq -c "[.[] | select(.severity == \"$SEV\")]")
        SEV_COUNT=$(echo "$SEV_ITEMS" | jq 'length')

        if [ "$SEV_COUNT" -eq 0 ]; then continue; fi

        SEV_UPPER=$(echo "$SEV" | tr '[:lower:]' '[:upper:]' | head -c1)
        SEV_REST=$(echo "$SEV" | cut -c2-)
        echo "## ${SEV_UPPER}${SEV_REST} ($SEV_COUNT)"
        echo ""
        echo "| Advisory | Package | Range | Location(s) |"
        echo "|----------|---------|-------|-------------|"

        echo "$SEV_ITEMS" | jq -r '.[] | "| [\(.id | split("/") | last)](\(.id)) | `\(.name)` | \(.range) | \(.locations | join(", ")) |"'
        echo ""
    done

    # Fix recommendations
    QUICK_FIXES=$(echo "$FIX_GROUPS" | jq '[.[] | select(.is_major == false)]')
    MAJOR_FIXES=$(echo "$FIX_GROUPS" | jq '[.[] | select(.is_major == true)]')
    QUICK_COUNT=$(echo "$QUICK_FIXES" | jq 'length')
    MAJOR_COUNT=$(echo "$MAJOR_FIXES" | jq 'length')

    if [ "$QUICK_COUNT" -gt 0 ] || [ "$MAJOR_COUNT" -gt 0 ]; then
        echo "## Fix Recommendations"
        echo ""

        if [ "$QUICK_COUNT" -gt 0 ]; then
            echo "### Quick Fixes (\`npm audit fix\`)"
            echo ""
            echo "$QUICK_FIXES" | jq -r '.[] | "- `\(.root_package)` (\(.vuln_count) vuln\(if .vuln_count > 1 then "s" else "" end)): \(.affected | join(", "))"'
            echo ""
        fi

        if [ "$MAJOR_COUNT" -gt 0 ]; then
            echo "### Requires Major Bump"
            echo ""
            echo "$MAJOR_FIXES" | jq -r '.[] | "- `\(.root_package)` → \(.fix_version) (\(.vuln_count) vuln\(if .vuln_count > 1 then "s" else "" end), semver-major): \(.affected | join(", "))"'
            echo ""
        fi
    fi

    # Acknowledged section
    if [ "$ACK_STILL_PRESENT" -gt 0 ]; then
        echo "## Acknowledged (suppressed)"
        echo ""
        echo "$CLEANED_ACK" | while IFS= read -r ack_id; do
            [ -z "$ack_id" ] && continue
            TITLE=$(echo "$DEDUPED_JSON" | jq -r --arg id "$ack_id" '.[] | select(.id == $id) | .title // "Unknown"')
            echo "- [$ack_id]($ack_id): $TITLE"
        done
        echo ""
    fi

    echo "---"
    echo "*Generated by check-vulns.sh. Run \`/check-vulns\` to review.*"
} > "$DIGEST_FILE"

# --- Write state ---
jq -nc \
    --argjson ts "$(date +%s)" \
    --argjson total "$TOTAL_VULNS" \
    --argjson critical "$CRITICAL_COUNT" \
    --argjson high "$HIGH_COUNT" \
    --argjson moderate "$MODERATE_COUNT" \
    --argjson low "$LOW_COUNT" \
    --argjson new "$NEW_COUNT" \
    --argjson pkgs "$PACKAGES_SCANNED" \
    --argjson known "$(echo "$CURRENT_IDS" | jq -R -s 'split("\n") | map(select(length > 0))')" \
    --argjson ack "$(echo "${CLEANED_ACK:-}" | jq -R -s 'split("\n") | map(select(length > 0))')" \
    '{
        checked_at: $ts,
        total_vulns: $total,
        by_severity: {critical: $critical, high: $high, moderate: $moderate, low: $low},
        known_advisories: $known,
        acknowledged: $ack,
        packages_scanned: $pkgs,
        new_count: $new
    }' > "$STATE_FILE"

# --- Emit observability event ---
HOOK_DIR="$PROJECT_ROOT/.claude/hooks"
if [ -f "$HOOK_DIR/_emit-event.sh" ]; then
    CLAUDE_LOGS_DIR="${CLAUDE_LOGS_DIR:-$PROJECT_ROOT/.claude/logs}"
    export CLAUDE_LOGS_DIR
    source "$HOOK_DIR/_emit-event.sh"
    emit_event "vuln_scan" "$(jq -nc \
        --argjson total "$TOTAL_VULNS" \
        --argjson critical "$CRITICAL_COUNT" \
        --argjson high "$HIGH_COUNT" \
        --argjson new_count "$NEW_COUNT" \
        --argjson resolved "$RESOLVED_COUNT" \
        --argjson pkgs "$PACKAGES_SCANNED" \
        '{total: $total, critical: $critical, high: $high, new: $new_count, resolved: $resolved, packages_scanned: $pkgs}'
    )"
fi

# --- Output ---
if [ "$IS_FIRST_RUN" = true ]; then
    echo "VULNS: Baseline — $TOTAL_VULNS found ($CRITICAL_COUNT critical, $HIGH_COUNT high). Run /check-vulns to review." >&2
elif [ "$UNACKED_NEW_COUNT" -gt 0 ]; then
    if [ "$CRITICAL_COUNT" -gt 0 ] || [ "$HIGH_COUNT" -gt 0 ]; then
        echo "VULNS: $UNACKED_NEW_COUNT new ($CRITICAL_COUNT critical, $HIGH_COUNT high). Run /check-vulns to review." >&2
    else
        echo "VULNS: $UNACKED_NEW_COUNT new vulnerability(ies). Run /check-vulns to review." >&2
    fi
elif [ "$RESOLVED_COUNT" -gt 0 ]; then
    echo "VULNS: $RESOLVED_COUNT vulnerability(ies) resolved since last scan." >&2
fi

if [ "$QUIET" = false ]; then
    cat "$DIGEST_FILE"
fi

exit 0
