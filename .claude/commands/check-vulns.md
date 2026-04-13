---
description: Check for npm security vulnerabilities across all packages. Use when checking security, auditing deps, or reviewing CVEs.
---

Check all package-lock.json files for known npm vulnerabilities using `npm audit` (GitHub Advisory Database).

## Check

Run `./scripts/check-vulns.sh --force` to bypass cache and scan now.

Then read the digest at `.claude/.update-cache/vulns-digest.md` and present findings to the user, organized by severity. Highlight:
1. Any **new** vulnerabilities since last scan
2. **Fix recommendations** (quick fixes vs major bumps)
3. **Acknowledged** vulns that are being tracked but suppressed

## Acknowledge Known Vulns

If the user wants to suppress session-start alerts for vulns that cannot be fixed yet (e.g., requires a semver-major bump):

1. Run `./scripts/check-vulns.sh --acknowledge <GHSA-URL>` where the URL is from the digest
2. The vuln still appears in the digest but won't trigger session-start alerts
3. Acknowledgements auto-clear when the vuln is resolved

## Fix Vulns

For quick fixes:
- Run `npm audit fix` in the affected directory
- Verify tests pass: `npm test`
- Commit lock file changes

For major-bump fixes:
- Cross-reference with `/check-deps` for the same package
- Review changelog and breaking changes before upgrading
- Apply with `npm install package@latest`

## Arguments

<user_request>
$ARGUMENTS
</user_request>
