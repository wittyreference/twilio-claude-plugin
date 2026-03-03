---
name: operational-gotchas
description: Cross-cutting debugging gotchas from real Twilio development sessions. Covers testing, serverless runtime, deployment, voice routing, ConversationRelay, Voice SDK, regional auth, and MCP environment issues.
---

# Operational Gotchas

Cross-cutting gotchas discovered through real debugging sessions. Domain-specific gotchas live in their respective skill files; these are the ones that span multiple domains or have no single home.

## Testing

- **Coverage summary JSON is cached** — After adding test files, must regenerate: `npx jest --coverage --coverageReporters=json-summary`.

- **`jest.doMock` for Runtime.getFunctions()** — Callback handlers use `Runtime.getFunctions()` at require-time. Use `jest.doMock(path, factory)` + `jest.resetModules()` in `beforeEach()`, not `jest.mock()` (which hoists before variable assignments).

- **`toContainEqual` for asymmetric matchers in arrays** — `toContain(expect.stringContaining())` uses `===` reference equality. Use `toContainEqual()` for deep equality with asymmetric matchers.

- **Newman E2E needs local server** — `npm run test:e2e` hits `localhost:3000`. Start `npm start` (twilio-run) first. Use `--timeout-request 5000` to avoid hangs.

- **`<Start><Recording>` hangs twilio-run locally** — Functions using `twiml.start().recording()` hang indefinitely on the local dev server and never return a response. Works fine deployed. Exclude these from local E2E tests; test against deployed serverless.

## Serverless Runtime

- **Twilio Functions have no built-in scheduler** — Functions are stateless HTTP handlers triggered by webhooks or direct HTTP calls. They cannot run on a cron/timer. For scheduled execution, use an external cron service (GitHub Actions, EasyCron, AWS EventBridge) that calls the Function's HTTP endpoint. Do not use `setInterval()` or cron libraries inside a Function — they won't persist between invocations.

- **`.protected.js` doesn't work with external cron callers** — Protected functions validate Twilio request signatures, which external cron services cannot provide. For cron-triggered functions, use a public `.js` endpoint with a shared-secret query parameter checked in the handler.

## Deployment

- **CLI `--value` flag double-escapes JSON strings** — `twilio api:...:variables:create --value '{"k":"v"}'` stores escaped JSON. Use `.env` file + redeploy instead for JSON env vars.

- **Inbound leg CallSid differs from outbound API call SID** — When initiating outbound to a tracking number, the function sees a different CallSid (inbound child). Sync docs keyed by inbound SID, recordings on outbound SID.

## Voice Call Routing

- **Empty `voiceUrl` on a Twilio number causes silent instant call failure** — When `make_call` targets a Twilio number that has no voice webhook configured (`voiceUrl: ""`), the call fails instantly with `duration: 0`. Twilio produces ZERO diagnostics: no debugger alerts, no call notifications, no error codes, no Voice Insights errors. The only symptom is `status: failed` with start_time === end_time. **Always verify destination number webhooks before troubleshooting call failures.**

## ConversationRelay & Voice Intelligence

- **`record: true` on make_call is ignored with ConversationRelay** — REST API recording param silently produces no recording when TwiML handler uses `<Connect><ConversationRelay>`. Always use `<Start><Recording>` in TwiML before ConversationRelay.

- **Language Operators run automatically on VI transcripts** — Conversation Summary and Sentiment Analysis produce results without explicit invocation if configured as default operators on the Intelligence service.

## Voice SDK / WebRTC

- **Voice SDK 2.x has no CDN** — Must serve `node_modules/@twilio/voice-sdk/dist/twilio.min.js` from own Express server. The 1.x CDN was deprecated April 2025.

- **SDK 2.x API changes from 1.x** — `device.register()` required (no auto-register), events are `'registered'`/`'unregistered'` (not `'ready'`/`'offline'`), `device.connect({ params: { To } })` returns Promise.

- **`Twilio.Response` is serverless-runtime-only** — Not in npm `twilio` package. Tests need MockResponse class. `jwt.AccessToken` IS in npm package.

- **CRITICAL: Voice SDK `connected` fires at A-leg, not B-leg bridge** — `device.connect()` reports `connected` when the browser connects to Twilio's WebRTC gateway, BEFORE the TwiML App dials the B-leg and it answers. A test completing in <2s for an outbound PSTN call is a false positive — real bridged calls take 3-5s minimum.

## Regional API & Authentication

- **Regional URL requires edge location** — `api.{edge}.{region}.twilio.com` (e.g. `api.sydney.au1.twilio.com`). Omitting the edge resolves to US infrastructure where regional API keys return 401.

- **API key auth cannot fetch `/Accounts/{SID}.json`** — Use `IncomingPhoneNumbers.json?PageSize=1` as a lightweight auth validation endpoint when using API keys.

- **Auth token rotation invalidates ALL API keys** — When the auth token is rotated/expired, every API key created under it dies. Only recovery: fresh auth token from Console → create new keys.

- **Twilio Node SDK auto-reads `TWILIO_REGION` and `TWILIO_EDGE` from env** — The SDK reads these env vars automatically even when not passed in the constructor options. Setting them in `.env` silently routes ALL API calls to regional infrastructure. If those calls use a US1 auth token, every request returns 401. Fix: comment out or unset `TWILIO_REGION`/`TWILIO_EDGE` when not actively testing regional endpoints.

## Claude Code & MCP

- **MCP server requires Claude Code restart after env changes** — The MCP server is a separate process that inherits the shell environment at launch. Mid-session changes to `.env` or exported variables do NOT propagate. Must quit and restart Claude Code entirely.

- **`.mcp.json` env block augments, doesn't replace parent env** — The MCP server subprocess inherits ALL env vars from the parent Claude Code process. The `env` block in `.mcp.json` adds or overrides individual vars but does not isolate the process.

- **`source .env` does not undo commented-out vars** — Shell variables persist in memory after commenting out lines in `.env`. Must explicitly `unset` vars before re-sourcing.

- **dotenv `{ override: true }` recommended** — `require('dotenv').config()` skips vars already in `process.env`. Use `{ override: true }` so `.env` always wins over inherited shell vars. Without this, users with pre-existing Twilio env vars from other projects hit silent auth failures. Run `env-doctor.sh` to diagnose conflicts.
