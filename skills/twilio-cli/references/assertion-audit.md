---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit for the Twilio CLI skill. Every factual claim pressure-tested. -->
<!-- ABOUTME: Proves provenance chain for all behavioral claims. 38 assertions extracted, audited 2026-03-25. -->

# Assertion Audit Log

**Skill**: twilio-cli
**Audit date**: 2026-03-25
**Account**: ACxx...xx
**Auditor**: Claude + MC

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 30 |
| CORRECTED | 0 |
| QUALIFIED | 8 |
| REMOVED | 0 |
| **Total** | **38** |

## Assertions

### Scope — CAN / CLI-Only (A1–A10)

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| A1 | Profile management is CLI-only | Scope | CONFIRMED | No MCP tools for profiles; twilio profiles:list live-tested | Live-verified |
| A2 | Serverless deployment is CLI-only | Scope | CONFIRMED | No MCP deploy tool; serverless:list showed 2 services | Live + architectural |
| A3 | Local dev server CLI-only | Scope | CONFIRMED | No MCP equivalent | Architectural |
| A4 | Deployment promotion CLI-only | Scope | CONFIRMED | serverless:promote has no MCP equivalent | Architectural |
| A5 | Deployment rollback CLI-only | Scope | CONFIRMED | serverless:activate has no MCP equivalent | Architectural |
| A6 | Live log tail CLI-only | Scope | CONFIRMED | serverless:logs --tail has no MCP equivalent | Architectural |
| A7 | Env var management CLI-only | Scope | QUALIFIED | serverless:env:* for deployed services; MCP has `create_variable`/`update_variable` for some env var ops | MCP has partial coverage via serverless tools |
| A8 | Plugin management CLI-only | Scope | CONFIRMED | plugins:* has no MCP equivalent | Architectural |
| A9 | Phone number purchase interactive | Scope | CONFIRMED | phone-numbers:buy:* is interactive search+buy | Docs + experience |
| A10 | Phone number release CLI | Scope | QUALIFIED | MCP has `release_phone_number` tool | CLI not exclusive; MCP also available |

### Scope — CANNOT (A11–A16)

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| A11 | CLI cannot be called from MCP | Architectural | CONFIRMED | tool-boundaries.md §Golden Rules, §ADR | Architectural boundary |
| A12 | CLI can't handle nested JSON | Behavioral | CONFIRMED | twilio-cli.md §Voice Intelligence Transcript | Documented workaround uses curl |
| A13 | profiles:create crashes Node 25.x | Behavioral | CONFIRMED | Memory: MCP onboarding invariants | Known issue |
| A14 | --profile unreliable on serverless:* | Behavioral | QUALIFIED | Operational experience; not systematically live-tested | May vary by CLI version |
| A15 | No CLI sync item-level operations | Scope | QUALIFIED | twilio-cli.md shows service/document only, not list-item/map-item | Not exhaustively verified |
| A16 | Boolean flags are presence-based | Behavioral | CONFIRMED | twilio-cli.md §Phone Number Search Filters | Documented + verified |

### Decision Framework (A17–A22)

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| A17 | MCP output is structured JSON | Architectural | CONFIRMED | All MCP tool responses return JSON | Tested across 5 domains |
| A18 | CLI output is tabular by default | Behavioral | CONFIRMED | serverless:list, profiles:list both show columns | Live-verified |
| A19 | Console-only: Pay Connectors | Scope | CONFIRMED | No REST API; CLAUDE.md confirms | Documented |
| A20 | Console-only: Trust Hub registration | Scope | QUALIFIED | Complex wizard; may have partial API | Docs suggest some API access |
| A21 | Console-only: Flex UI config | Scope | QUALIFIED | Visual editor | May have API for some config |
| A22 | Console-only: Studio Flow visual editor | Scope | QUALIFIED | Drag-and-drop | API exists for flow CRUD, but visual editing is Console-only |

### Gotchas (A23–A34)

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| A23 | [env] profile takes precedence | Behavioral | CONFIRMED | profiles:list showed [env] as active with env vars set | Live-verified |
| A24 | profiles:create crashes Node 25.x | Behavioral | CONFIRMED | Same as A13 | — |
| A25 | .twiliodeployinfo stale cache causes 20404 | Behavioral | CONFIRMED | twilio-cli.md §Troubleshooting | Documented |
| A26 | --override-existing-project is destructive | Behavioral | CONFIRMED | twilio-cli.md §Deployment | Documented |
| A27 | punycode deprecation on Node 22+ | Behavioral | CONFIRMED | serverless:list showed [DEP0040] warning | Live-verified |
| A28 | --production flag affects domain | Behavioral | CONFIRMED | twilio-cli.md §Deployment | Documented |
| A29 | -o json for machine-readable | Behavioral | CONFIRMED | Standard CLI flag | Verified |
| A30 | CLI can't handle nested JSON | Behavioral | CONFIRMED | Same as A12 | — |
| A31 | Never use twilio api:* when MCP exists | Architectural | CONFIRMED | CLAUDE.md §MCP-first rule | Project policy |
| A32 | CLI only for profiles, serverless, plugins | Scope | QUALIFIED | Simplified rule; phone-numbers:buy is also CLI-recommended | Slightly oversimplified |
| A33 | Wrong profile gives clear error | Behavioral | CONFIRMED | "The profile 'nonexistent' does not exist" | Live-verified |
| A34 | CLI version 6.2.4 on test system | Behavioral | CONFIRMED | twilio --version output | Live-verified |

### SID Reference (A35–A38)

| # | Assertion | Category | Verdict | Evidence | Notes |
|---|-----------|----------|---------|----------|-------|
| A35 | ZS = Serverless Service | Scope | CONFIRMED | serverless:list showed ZS-prefixed SIDs | Live-verified |
| A36 | ZB = Serverless Build | Scope | CONFIRMED | twilio-cli.md §Rollback | Documented |
| A37 | ZE = Serverless Environment | Scope | CONFIRMED | twilio-cli.md §Promote | Documented |
| A38 | NO = Debugger Alert | Scope | CONFIRMED | twilio-cli.md §Debugger | Documented |

## Qualifications Applied

### Q1: Env var management (A7)
- **Condition**: MCP has `create_variable` and `update_variable` tools for serverless env vars. CLI `serverless:env:*` is more complete (import, unset) but not exclusive.

### Q2: Phone number release (A10)
- **Condition**: MCP `release_phone_number` tool exists. CLI is not the only option.

### Q3: --profile on serverless:* (A14)
- **Condition**: Based on operational experience, not systematic testing. May depend on CLI version.

### Q4: Sync item-level CLI (A15)
- **Condition**: Not exhaustively tested. CLI may have undocumented item-level commands.

### Q5-Q7: Console-only operations (A20-A22)
- **Condition**: Trust Hub, Flex, and Studio may have partial API coverage. "Console-only" refers to the visual editing experience, not all CRUD operations.

### Q8: CLI-only simplified rule (A32)
- **Condition**: The rule "CLI only for profiles, serverless, plugins" is a simplification. `phone-numbers:buy` is also CLI-recommended due to its interactive nature.
