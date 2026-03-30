---
description: Check for outdated dependencies across all packages. Use when checking deps, bumping versions, or managing package freshness.
---

Check all package.json files for outdated dependencies and apply safe bumps.

## Check

Run `./scripts/check-deps.sh --force` to bypass cache and check now. Report the output to the user.

Then read the digest file at `.update-cache/deps-digest.md` and present the findings.

## Apply Safe Bumps

If the user wants to apply safe bumps (within declared semver range):

1. Run `npm update` in each directory that has outdated packages
2. For TypeScript packages, verify compilation: `npx tsc --noEmit`
3. For the MCP server (`twilio/`), also run `npm run build`
4. Commit all lock file changes with a descriptive message listing what was bumped

## Major Upgrades

For packages with major version jumps, present them separately with a recommendation:

- **Review changelog** — link to the package's changelog/release notes
- **Check breaking changes** — note known migration concerns
- **Defer or adopt** — recommend based on risk vs. benefit

Known major upgrade concerns:
- `jest` 29→30: Test runner migration, possible config changes
- `typescript` 5→6: Compiler changes, check `tsconfig.json` compat
- `zod` 3→4: Schema API changes, affects MCP server + feature-factory
- `dotenv` 16→17: Requires `quiet: true` to suppress stdout logging
- `@anthropic-ai/sdk` 0.x: Pre-1.0, any minor bump can break

## Arguments

<user_request>
$ARGUMENTS
</user_request>
