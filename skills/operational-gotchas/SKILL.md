---
name: "operational-gotchas"
description: "Twilio development skill: operational-gotchas"
---

# Operational Gotchas

Cross-cutting gotchas discovered through real debugging sessions. Domain-specific gotchas live in their respective CLAUDE.md files; these are the ones that span multiple domains or have no single home.

## SIP Connectivity Taxonomy

- **SIP Interface ≠ Elastic SIP Trunking** — These are distinct products. SIP Interface (also called SIP Domains, Programmable SIP) connects SIP infrastructure to Programmable Voice with full TwiML/API access. Elastic SIP Trunking is a pure PSTN conduit that bypasses PV entirely. BYOC is a type of SIP Interface for non-ported carrier numbers. The decision is: need TwiML? → SIP Interface. Just need cheap PSTN pipe? → Elastic SIP Trunking.

- **IP ACLs and Credential Lists are account-level resources** — They are NOT subresources of trunks or domains. They can be shared between SIP Domains and SIP Trunks. Up to 1000 of each per account.

- **SIP Registration is SIP Interface only** — Elastic SIP Trunking is INVITE-only. No registration required or supported. SIP Registration is for PV SIP use cases (agent desk phones, softphone apps).

- **Phone number can only be trunk OR PV, not both** — Assigning a number to a SIP trunk removes its voice webhook. They are mutually exclusive on a per-number basis. SIP Interface and Elastic SIP Trunking can coexist on the same account for different numbers.

## CLI Profile and .env Independence

- **CLI profile and `.env` are independent auth sources** — The Twilio CLI profile can point to the main account while `.env` has a subaccount SID, or vice versa. They do not share state. Always check both before operations: `twilio profiles:list` for CLI context, and `.env` contents for SDK/serverless context. Deploying with one profile while `.env` targets a different account causes silent misrouting.

## Testing

- **Coverage summary JSON is cached** — `pre-bash-validate.sh` reads `coverage/coverage-summary.json` and considers it fresh if newer than `package.json`. After adding test files, must regenerate: `npx jest --coverage --coverageReporters=json-summary`.

- **`jest.doMock` for Runtime.getFunctions()** — Callback handlers use `Runtime.getFunctions()` at require-time. Use `jest.doMock(path, factory)` + `jest.resetModules()` in `beforeEach()`, not `jest.mock()` (which hoists before variable assignments).

- **`toContainEqual` for asymmetric matchers in arrays** — `toContain(expect.stringContaining())` uses `===` reference equality. Use `toContainEqual()` for deep equality with asymmetric matchers.

- **Newman E2E needs local server** — `npm run test:e2e` hits `localhost:3000`. Start `npm start` (twilio-run) first. Use `--timeout-request 5000` to avoid hangs.

- **`<Start><Recording>` hangs twilio-run locally** — Functions using `twiml.start().recording()` hang indefinitely on the local dev server and never return a response. Affected: ivr-welcome, notification-outbound, outbound-customer-leg, sales-dialer-prospect, call-tracking-inbound, contact-center-welcome. Works fine deployed. E2E tests exclude these for local runs; use `npm run test:e2e:deployed` for full coverage.

## Serverless Runtime

- **Twilio Functions have no built-in scheduler** — Functions are stateless HTTP handlers triggered by webhooks or direct HTTP calls. They cannot run on a cron/timer. For scheduled execution, use an external cron service (GitHub Actions, EasyCron, AWS EventBridge) that calls the Function's HTTP endpoint. Studio Flows with scheduled triggers are an alternative within the Twilio ecosystem. Do not use `setInterval()` or cron libraries inside a Function — they won't persist between invocations.

- **`.protected.js` doesn't work with external cron callers** — Protected functions validate Twilio request signatures, which external cron services cannot provide. For cron-triggered functions, use a public `.js` endpoint with a shared-secret query parameter checked in the handler.

## Deployment

- **`services.json` only supports single-level directory names**: Using `voice/orange` as a directory entry fails because the deploy script can't create nested symlinks. Use flat names like `orange` → ``.

- **Twilio Serverless env var context limit is 3583 bytes**: The deploy script auto-filters to only vars referenced via `context.VAR_NAME` in each service's functions. To fix an already over-limit service: delete the service and re-deploy fresh — `--override-existing-project` checks the EXISTING service's context first and rejects before applying the new deploy.

- **macOS `grep -R --include` does NOT follow symlinks**: The deploy build dir uses symlinks to source directories. `grep -R` silently returns empty results. Use `find -L ... -exec grep` instead.

- **CLI `--value` flag double-escapes JSON strings** — `twilio api:...:variables:create --value '{"k":"v"}'` stores escaped JSON. Use `.env` file + redeploy instead for JSON env vars.

- **Inbound leg CallSid differs from outbound API call SID** — When initiating outbound to a tracking number, the function sees a different CallSid (inbound child). Sync docs keyed by inbound SID, recordings on outbound SID.

- **TwiML App voice URL drifts after redeployment** — The Serverless Toolkit can change the deployment domain between deploys (e.g. `prototype-2504-dev.twil.io` → `prototype-1483-dev.twil.io`). The TwiML App SID (`TWILIO_VOICE_SDK_APP_SID`) stores an absolute voice URL that does NOT auto-update when the domain changes. This causes Voice SDK error 21005 (HTTP connection failure) because the TwiML App points to the old dead domain. After every `twilio serverless:deploy`, verify and update the TwiML App's voice URL to match the new domain.

## Verify API

- **Verify Service FriendlyName rejects names with 5+ total digits (error 60200)** — `POST /v2/Services` returns "Invalid parameter" if the FriendlyName contains 5 or more digit characters total, even non-consecutive (e.g. `test-20260307-abc` has 8 digits). Convert numeric identifiers to alpha-only hash: `echo "$TS" | md5 | tr '0-9' 'g-p' | head -c 8`.

## Voice Call Routing

- **REST API `Twiml` parameter for inline TwiML** — `POST .../Calls.json` accepts a `Twiml` parameter with inline TwiML instead of requiring a `Url` webhook. Useful for provisioning tests and one-off calls. CLI equivalent: `twilio api:core:calls:create --twiml '<Response><Say>Hello</Say></Response>'`.

- **Empty `voiceUrl` on a Twilio number causes silent instant call failure** — When `make_call` targets a Twilio number that has no voice webhook configured (`voiceUrl: ""`), the call fails instantly with `duration: 0`. Twilio produces ZERO diagnostics: no debugger alerts, no call notifications, no error codes, no Voice Insights errors. The only symptom is `status: failed` with start_time === end_time. This wastes enormous debugging time because it looks identical to auth failures, regional routing issues, or account-level blocks. **Always verify destination number webhooks before troubleshooting call failures.** Use `list_phone_numbers` and check that every number involved in testing has a non-empty `voiceUrl`.

## ConversationRelay & Voice Intelligence

- **`record: true` on make_call is ignored with ConversationRelay** — REST API recording param silently produces no recording when TwiML handler uses `<Connect><ConversationRelay>`. Always use `<Start><Recording>` in TwiML before ConversationRelay.

- **Agent-to-agent ConversationRelay setup is not optional** — It produces the multi-turn transcripts needed to validate topic keywords and conversation quality. Using a generic IVR handler produces meaningless transcripts.

- **Language Operators run automatically on VI transcripts** — Conversation Summary and Sentiment Analysis produce results without explicit invocation if configured as default operators on the Intelligence service.

## Voice SDK / WebRTC

- **Voice SDK 2.x has no CDN** — Must serve `node_modules/@twilio/voice-sdk/dist/twilio.min.js` from own Express server. The 1.x CDN was deprecated April 2025.

- **SDK 2.x API changes from 1.x** — `device.register()` required (no auto-register), events are `'registered'`/`'unregistered'` (not `'ready'`/`'offline'`), `device.connect({ params: { To } })` returns Promise.

- **`Twilio.Response` is serverless-runtime-only** — Not in npm `twilio` package. Tests need MockResponse class. `jwt.AccessToken` IS in npm package.

- **TwiML App SID** (`APxxx`) stored as `TWILIO_VOICE_SDK_APP_SID` in `.env` and serverless env vars.

- **Playwright + Chromium handles WebRTC** — Use `--use-fake-device-for-media-stream` + `--use-fake-ui-for-media-stream`. Server-side validation covers what browser-side can't.

- **CRITICAL: Voice SDK `connected` fires at A-leg, not B-leg bridge** — `device.connect()` reports `connected` when the browser connects to Twilio's WebRTC gateway, BEFORE the TwiML App dials the B-leg and it answers. A test completing in <2s for an outbound PSTN call is a false positive — real bridged calls take 3-5s minimum. Always sanity-check test durations against real-world call setup latency.

- **Never report Twilio E2E test results without checking timing** — Green tests with suspiciously fast durations are likely testing signaling only, not actual media/audio bridging. Verify call duration via REST API or add explicit post-bridge waits + duration assertions.

## Regional API & Authentication

- **Regional URL requires edge location** — `api.{edge}.{region}.twilio.com` (e.g. `api.sydney.au1.twilio.com`). Omitting the edge (e.g. `api.au1.twilio.com`) resolves to US infrastructure where regional API keys return 401.

- **API key auth cannot fetch `/Accounts/{SID}.json`** — The account fetch endpoint requires auth token auth specifically. API keys work for all other endpoints. Use `IncomingPhoneNumbers.json?PageSize=1` as a lightweight auth validation endpoint when using API keys.

- **Auth token rotation invalidates ALL API keys** — When the auth token is rotated/expired, every API key created under it dies. Regional and US keys all fail simultaneously. Only recovery: fresh auth token from Console → create new keys.

- **Twilio Node SDK regional constructor** — `Twilio(apiKeySid, apiKeySecret, { accountSid, region: 'au1', edge: 'sydney' })` for API key auth. `Twilio(accountSid, authToken, { region, edge })` for auth token auth. The MCP server's `createTwilioMcpServer()` supports both via `TWILIO_API_KEY`/`TWILIO_API_SECRET`/`TWILIO_REGION`/`TWILIO_EDGE` env vars.

- **Twilio Node SDK auto-reads `TWILIO_REGION` and `TWILIO_EDGE` from env** — The SDK reads these env vars automatically even when not passed in the constructor options. Setting them in `.env` silently routes ALL API calls to regional infrastructure (`api.{edge}.{region}.twilio.com`). If those calls use a US1 auth token, every request returns 401. Symptoms: cascading auth failures across unrelated tests with no obvious cause. Fix: comment out or unset `TWILIO_REGION`/`TWILIO_EDGE` when not actively testing regional endpoints.

## Claude Code & MCP

- **MCP server requires Claude Code restart after env changes** — The MCP server is a separate process that inherits the shell environment at launch. Mid-session changes to `.env` or exported variables do NOT propagate. Must quit and restart Claude Code entirely.

- **`.mcp.json` env block augments, doesn't replace parent env** — The MCP server subprocess inherits ALL env vars from the parent Claude Code process. The `env` block in `.mcp.json` adds or overrides individual vars but does not isolate the process. To prevent inherited `TWILIO_REGION`/`TWILIO_EDGE` from contaminating the MCP server, explicitly set them to empty strings in `.mcp.json`.

- **`source .env` does not undo commented-out vars** — Shell variables persist in memory after commenting out lines in `.env`. Must explicitly `unset TWILIO_REGION TWILIO_EDGE` etc. before re-sourcing. This interacts badly with MCP (which also needs a restart to pick up the unset).

- **dotenv `{ override: true }` is project-wide policy** — All `require('dotenv').config()` calls in this project use `{ override: true }` so `.env` values always win over inherited shell vars. The shipped `.envrc` provides the same isolation for shell scripts via explicit `unset` before loading. New users with pre-existing Twilio env vars (from `.zshrc`, other projects, or Twilio CLI) would otherwise hit silent auth failures. Run `./scripts/env-doctor.sh` to diagnose conflicts.

## Hooks & Documentation Flywheel

- **Hooks receive tool input on stdin as JSON, not env vars** — `CLAUDE_TOOL_INPUT_FILE_PATH`, `CLAUDE_TOOL_INPUT_COMMAND`, `CLAUDE_TOOL_INPUT_CONTENT` don't exist. Parse stdin with `jq`: `FILE_PATH="$(cat | jq -r '.tool_input.file_path // empty')"`. All 4 hooks (pre-bash-validate, pre-write-validate, post-write, post-bash) were silently broken until fixed.

- **Flywheel must exclude its own output files** — Editing `pending-actions.json` triggers post-write, which tracks it in `.session-files`, which the next flywheel run picks up, generating infinite recursive suggestions. Filter out `pending-actions.json`, `.session-files`, `.session-start`, `.last-doc-check` from the file collection.

- **Pending actions auto-clear only works for concrete paths** — Entries with vague targets ("Relevant CLAUDE.md") or gitignored paths (`todo.md`) never match staged files and accumulate forever. Always use specific file paths in suggestions.

- **Flywheel has 4 sources** — git status (uncommitted), recent commits (since session start), session-tracked files (.session-files), validation failure patterns (pattern-db.json). Source 3 was broken until the stdin fix.

- **Meta-mode hook blocks writes outside project root** — `pre-write-validate.sh` prefix-strips `PROJECT_ROOT/` from `FILE_PATH`. When path is outside the project (e.g., `~/plans/`), the strip is a no-op, leaving an absolute path that matches no allowed patterns. Fixed: wrapped case block in `if [[ "$RELATIVE_PATH" != "$FILE_PATH" ]]`.

## Hooks & Worktrees

- **Merge conflicts in hook scripts create a deadlock** — If both `pre-bash-validate.sh` and `pre-write-validate.sh` have conflict markers simultaneously, ALL Claude Code tools (Bash, Edit, Write) are blocked because the hooks themselves fail to parse. The only escape is the user running a manual command via `!` or `git checkout --theirs/--ours`. Prevention: when merging branches that touch hook scripts, resolve hook conflicts first. Hooks resolve from the main repo path even when working in a worktree.

- **Worktree cleanup race with background agents** — Background agents can remove the worktree directory while the main session is still using it. Recovery: `git fsck --unreachable --no-reflogs` to find dangling commits, recreate branch from tip, merge.

- **CC settings.json hook type names are schema-validated at edit time only** — The settings.json schema rejects unknown hook type names when the Edit tool writes to it. An invalid type name (e.g., `PermissionDenied` instead of `PermissionRequest`) is silently ignored at runtime — schema validation during editing is your only safety net.

## Twilio API Quirks

- **Geographic Permissions API booleans must be strings** — `client.voice.v1.dialingPermissions.bulkCountryUpdates.create()` accepts a JSON string of update objects where boolean values must be `"true"`/`"false"` (strings), not actual booleans. Passing native booleans silently fails.

- **GitHub branch protection requires prior CI runs** — The "Add checks" search in GitHub rulesets only shows status checks that have previously run against the default branch via a PR. If you've only pushed directly to main, the check names won't appear. Push via PR first, then add the check.

## Sierra Stack (Pre-GA)

- **IP-based auth restrictions on pre-GA APIs** — Conversations v2, Customer Memory, and CI v3 APIs reject requests from cloud VM IPs (DigitalOcean, AWS, etc.) with 401 "invalid username". Same credentials work from local machines. Pre-GA demos must run from a trusted/registered IP. (Discovered 2026-04-03)

- **ENVIRONMENT=dev routes to non-existent regional endpoints** — TAC SDK reads `ENVIRONMENT` env var and constructs URLs like `conversations.dev-us1.twilio.com`. These don't resolve → `ENOTFOUND` → "fetch failed". Always use `ENVIRONMENT=prod` or omit (defaults to prod). (Discovered 2026-04-03)

- **CI v3 operator PUT creates an inactive version with no activation API** — Updating a pre-GA operator via PUT creates a new version but does not activate it. The operator silently stops producing results. No REST API to activate a version. Must delete and POST to recreate. (Discovered 2026-04-03)

- **CI v3 API response shapes differ from v2 and from docs** — List endpoints return `items[]` not `operatorResults[]` or `conversations[]`. Operator results use `result.label` not `output.label`. Dates are `dateCreated` not `createdAt`. Channels are `channels[]` array not `channel` string. Pagination uses `meta.nextToken` not `nextPageUrl`. Operator results don't include `displayName` — only `operator.id`; resolve names via separate `GET /v3/ControlPlane/Operators`. (Discovered 2026-04-06)

## ngrok

- **Dead ngrok tunnel returns 404 HTML, not connection refused** — When an ngrok tunnel is offline, requests to the domain return HTTP 404 with an ngrok-branded HTML error page. `curl -s -o /dev/null -w "%{http_code}"` shows 404, which looks identical to a missing route on your server. Always check the response body or verify via `curl -s https://DOMAIN/health | head -1` to distinguish ngrok error page from your server's 404.

- **`localhost:4040/api/tunnels` can show tunnel as "active" when forwarding is dead** — The ngrok agent API reports tunnel entries that are no longer forwarding traffic. The only reliable check is an end-to-end request through the tunnel to your server's health endpoint.

- **Twilio produces ZERO diagnostics when callback URLs are unreachable** — `<Start><Recording>`, `<Start><Transcription>`, `<Start><Stream>`, and ConversationRelay WebSocket connections all fail silently when the target URL/domain is unreachable. No debugger alerts, no call notifications, no error events. The call continues but no data flows. When ConversationRelay + Real-Time Transcription + Media Streams all fail simultaneously, suspect ngrok/infrastructure before platform. (Discovered 2026-04-06)

## Cross-Account SID Mismatch

**Scenario**: Deploy to a new subaccount but env vars (TWILIO_TASKROUTER_WORKSPACE_SID, TWILIO_SYNC_SERVICE_SID, TWILIO_VERIFY_SERVICE_SID) still reference the old account. Resources return 404.

**Detection**: Use `validate_environment()` MCP tool at session start. It verifies all SID env vars resolve against the current account.

**Prevention**: After switching accounts (`twilio profiles:use`), re-run `npm run setup` or `./scripts/bootstrap.sh` to re-provision resources. The MCP server inherits env at launch, not runtime — restart Claude Code after .env changes.

**Gotcha**: CLI profile and .env are independent. `twilio profiles:list` shows one account; `.env` may point to another. Always check both.
