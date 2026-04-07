---
name: "twilio-cli"
description: "Twilio development skill: twilio-cli"
---

---
name: twilio-cli
description: Twilio CLI decision guide. Use when choosing between CLI, MCP tools, Console, or SDK for a Twilio operation — profiles, deployment, serverless toolkit, and CLI-only operations.
---

<!-- verified: twilio CLI 6.2.4, Node 22.22.1, live profile/serverless testing 2026-03-25 -->

# Twilio CLI Decision Guide

When to use the Twilio CLI vs MCP tools vs Console vs SDK. Covers CLI-only operations, profile management, serverless deployment, and the operational boundaries between tooling layers.

Evidence date: 2026-03-25. CLI version: 6.2.4. Node: v22.22.1. Account prefix: AC...

**This skill is a decision guide, not a command reference.** For command syntax, see `references/twilio-cli.md`. For the full MCP vs CLI vs Functions boundary framework, see `references/tool-boundaries.md`.

## Scope

### CAN (CLI-Only Operations — No MCP Equivalent)

- **Profile management**: `profiles:create`, `profiles:list`, `profiles:use`, `profiles:remove` — credential storage and multi-account switching <!-- verified: twilio profiles:list showed 4 profiles -->
- **Serverless deployment**: `serverless:deploy` — deploy functions and assets to Twilio infrastructure <!-- verified: twilio serverless:list showed 2 services -->
- **Local development server**: `serverless:start --ngrok` — local function execution with tunnel
- **Deployment promotion**: `serverless:promote` — promote builds between environments
- **Deployment rollback**: `serverless:activate` — activate a previous build
- **Serverless logging**: `serverless:logs --tail` — live tail of deployed function logs
- **Environment variable management**: `serverless:env:set`, `serverless:env:import` — set vars on deployed services
- **Plugin management**: `plugins:install`, `plugins:update`, `plugins:uninstall`
- **Phone number purchase** (interactive): `phone-numbers:buy:local`, `phone-numbers:buy:toll-free` — search + buy in one flow
- **Phone number release**: `api:core:incoming-phone-numbers:remove`

### CANNOT

- **Cannot be called from MCP tools** — MCP never invokes CLI. This is an architectural boundary, not a limitation. See `references/tool-boundaries.md`. <!-- verified: tool-boundaries.md §Golden Rules -->
- **Cannot handle nested JSON parameters** — CLI parameter parsing breaks on complex nested JSON (e.g., Voice Intelligence `Channel` param). Use `curl` for these. <!-- verified: references/twilio-cli.md §Troubleshooting -->
- **`profiles:create` crashes on Node 25.x** — readline incompatibility. Users must manually create `~/.twilio-cli/config.json`. <!-- verified: memory, MCP onboarding invariants -->
- **`--profile` flag on `serverless:*` commands is unreliable** — Serverless commands may ignore `--profile` and use the active profile. Always `profiles:use` first. <!-- verified: operational experience -->
- **No `twilio api:sync:*` item-level operations** — CLI has service/document CRUD but no list-item or map-item commands. Use MCP or SDK. <!-- verified: twilio-cli.md §Sync -->
- **Presence-based boolean flags** — `--voice-enabled` is correct, `--voice-enabled=true` is NOT. Flags are presence-based, not key=value. <!-- verified: twilio-cli.md §Phone Number Search Filters -->

## Quick Decision

| Need | Use | Why |
|------|-----|-----|
| Query calls, messages, recordings | MCP tools | Structured JSON, agent-accessible |
| Send test SMS or make test call | MCP tools | Rate-limited, validated |
| Deploy serverless functions | CLI `serverless:deploy` | CLI-only operation |
| Switch Twilio account | CLI `profiles:use` | CLI-only operation |
| Purchase phone number | CLI `phone-numbers:buy:*` | Interactive confirmation, financial |
| Configure webhook URLs | MCP `configure_webhook` | Automated, scriptable |
| Check debugger errors | MCP `get_debugger_logs` or `validate_*` | SID-first principle |
| Manage Sync data | MCP tools | Full CRUD, structured responses |
| Manage TaskRouter | MCP tools (30 tools) | Full coverage |
| Local function development | CLI `serverless:start` | CLI-only operation |
| Rollback deployment | CLI `serverless:activate` | CLI-only operation |
| View deployed function logs | CLI `serverless:logs --tail` | CLI-only live tail |
| One-off manual inspection | CLI `api:*` commands | Human debugging |
| Complex nested JSON params | `curl` (REST API directly) | CLI can't handle nested JSON |

## Decision Framework

### MCP vs CLI vs Console

| Criterion | MCP Tools | CLI | Console |
|-----------|-----------|-----|---------|
| **Who uses it** | Claude/agents | Developers in terminal | Humans in browser |
| **Output format** | Structured JSON | Tabular/text | Visual UI |
| **Automation** | Full | Scriptable | Manual only |
| **Auth model** | .env / CLI profile / env vars | CLI profiles | Browser session |
| **Best for** | Data queries, sends, CRUD | Deployment, profiles, purchase | Pay Connectors, visual config |
| **Risk model** | Tier 1-3 guardrails | Human judgment | Human judgment |

### CLI-Only vs MCP-Available

| Operation | CLI | MCP | Notes |
|-----------|-----|-----|-------|
| Profile management | `profiles:*` | — | CLI-only |
| Serverless deploy/promote/rollback | `serverless:*` | — | CLI-only |
| Local dev server | `serverless:start` | — | CLI-only |
| Plugin management | `plugins:*` | — | CLI-only |
| Send SMS | `api:core:messages:create` | `send_sms` | **Prefer MCP** |
| Make call | `api:core:calls:create` | `make_call` | **Prefer MCP** |
| List phone numbers | `phone-numbers:list` | `list_phone_numbers` | **Prefer MCP** |
| Search numbers | `api:core:available-phone-numbers:*` | `search_available_numbers` | **Prefer MCP** |
| Purchase number | `phone-numbers:buy:*` or `api:core:incoming-phone-numbers:create` | `purchase_phone_number` | MCP available but CLI recommended (interactive) |
| Configure webhooks | `phone-numbers:update` | `configure_webhook` | **Prefer MCP** |
| Debugger logs | `debugger:logs:list` | `get_debugger_logs` | **Prefer MCP** (SID-first) |
| Sync operations | Limited `api:sync:*` | Full CRUD (21 tools) | **Prefer MCP** |
| TaskRouter operations | `api:taskrouter:*` | Full CRUD (30 tools) | **Prefer MCP** |
| Proxy operations | — | 17 tools (source only, not loaded) | REST API via curl |
| Verify operations | `api:verify:*` | `start_verification`, `check_verification` | **Prefer MCP** |

### Console-Only Operations (No CLI or MCP)

| Operation | Why Console-Only |
|-----------|-----------------|
| Pay Connectors configuration | No REST API exists |
| Trust Hub / A2P 10DLC registration | Complex multi-step wizard |
| Flex UI configuration | Visual layout editor |
| Studio Flow visual editor | Drag-and-drop flow builder |

## Profile Management

### The `[env]` Profile

When `TWILIO_ACCOUNT_SID` and `TWILIO_AUTH_TOKEN` are set as environment variables, the CLI auto-creates a virtual `[env]` profile that takes precedence over stored profiles. This is the default in this project (`.env` file loaded by direnv).

### Multi-Account Safety

**Always verify the active profile before deploying.** Multi-account setups are common and deploying to the wrong account is hard to detect.

```bash
# Check which account is active
twilio profiles:list

# Switch to the correct account
twilio profiles:use my-project

# Verify with an API call
twilio api:core:accounts:fetch
```

### Profile Storage

Profiles are stored in `~/.twilio-cli/config.json`. The MCP server's credential resolver reads this file as a fallback: `process.env` → `.env` → CLI profile.

## Serverless Deployment

### Key Files

| File | Purpose | Gotcha |
|------|---------|--------|
| `.twilioserverlessrc` | Service name, folders, env path | Must exist for deploy |
| `.twiliodeployinfo` | Cached `{accountSid:region → serviceSid}` | **Stale cache causes 20404 on deploy** |
| `.env` | Local environment variables | Deployed separately via `serverless:env:import` |

### The `.twiliodeployinfo` Trap

After first deploy, `.twiliodeployinfo` caches the service SID. If the service is deleted but the cache isn't cleared, subsequent deploys fail with error 20404. Fix: `echo '{}' > .twiliodeployinfo`.

### Deploy vs Promote

| Method | Use When | What Happens |
|--------|----------|-------------|
| `serverless:deploy` | New code changes | Builds + deploys to target environment |
| `serverless:promote` | Promote existing build | Copies build from source to target env (no rebuild) |
| `serverless:activate` | Rollback | Activates a previous build SID |

## Gotchas

### Profiles & Auth

1. **`[env]` profile takes precedence**: If `TWILIO_ACCOUNT_SID` is set in environment, the CLI uses it regardless of `profiles:use`. Unset env vars to use stored profiles. [Evidence: profiles:list showed `[env]` as active]

2. **`profiles:create` crashes on Node 25.x**: readline incompatibility. Workaround: manually create `~/.twilio-cli/config.json`. [Evidence: memory, MCP onboarding invariants]

3. **Verify profile before every deploy**: `twilio profiles:list` — the active account may not be what you expect, especially with `[env]` overriding stored profiles.

### Deployment

4. **`.twiliodeployinfo` stale cache**: Deleting a service without clearing this cache causes 20404 on next deploy. Fix: `echo '{}' > .twiliodeployinfo`. [Evidence: references/twilio-cli.md §Troubleshooting]

5. **`--override-existing-project` is destructive**: Overwrites the entire service. All functions and assets are replaced, not merged. Previous URLs may break if functions were renamed or removed.

6. **`punycode` deprecation warning on Node 22+**: Cosmetic warning `[DEP0040]` on every CLI command. Harmless but noisy. [Evidence: serverless:list output]

7. **`--production` flag affects domain name**: `serverless:deploy --production` changes the URL format. Without it, URLs include the environment name as a subdomain.

### Command Syntax

8. **Boolean flags are presence-based**: `--voice-enabled` (correct), NOT `--voice-enabled=true` (wrong). This applies to all boolean flags on search/buy commands. [Evidence: twilio-cli.md §Phone Number Search Filters]

9. **`-o json` for machine-readable output**: Always use `-o json` when parsing CLI output programmatically. Default columnar output is for human readability only.

10. **CLI can't handle nested JSON**: Operations requiring complex nested JSON parameters (like Voice Intelligence transcript creation with `Channel`) must use `curl` with the REST API directly. [Evidence: twilio-cli.md §Voice Intelligence]

### MCP vs CLI Confusion

11. **Never use `twilio api:*` when MCP tool exists**: The CLAUDE.md MCP-first rule. CLI `api:*` commands are for human debugging only. MCP tools provide structured JSON, rate limiting, and agent accessibility. [Evidence: CLAUDE.md §MCP Server & Tool Discovery]

12. **CLI is only for `profiles:*`, `serverless:*`, `plugins:*`**: These three command families have no MCP equivalent. Everything else has an MCP tool and should use it.

## SID Reference (CLI Output)

| Prefix | Resource | CLI Command |
|--------|----------|-------------|
| `ZS` | Serverless Service | `serverless:list` |
| `ZE` | Serverless Environment | `serverless:list environments` |
| `ZB` | Serverless Build | `serverless:list builds` |
| `ZH` | Serverless Function | `serverless:list functions` |
| `NO` | Debugger Alert | `debugger:logs:list` |

## Related Resources

- **CLI command reference** (`references/twilio-cli.md`) — Full command syntax, flags, examples (1012 lines)
- **Tool boundaries** (`references/tool-boundaries.md`) — MCP vs CLI vs Functions decision framework, risk tiers, anti-patterns
- **Phone numbers skill** (`skills/phone-numbers/SKILL.md`) — Number search, purchase, webhook configuration
- **CLAUDE.md** (`/CLAUDE.md`) — MCP-first rule, deployment verification
- **Operational gotchas** (`references/operational-gotchas.md`) — Cross-cutting deployment and testing issues

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| CLI-only command syntax | `references/command-reference.md` | Need exact CLI syntax for profiles, deploy, promote, rollback, plugins |
| Full CLI reference (1000+ lines) | `references/twilio-cli.md` | Need CLI syntax for API commands (messages, calls, conferences, recordings) |
| Assertion audit | `references/assertion-audit.md` | Adversarial audit of every factual claim |
