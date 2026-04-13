---
name: "voice"
description: "Twilio development skill: voice"
---

# ABOUTME: Context and reference for Twilio Voice API serverless functions.
# ABOUTME: Covers file inventory, TwiML control model, webhooks, and critical gotchas.


**Service:** `prototype-core` (`CORE_BASE_URL`). Deploy: `./scripts/deploy-services.sh dev`

For detailed verb options, code patterns, and conference API examples, see [REFERENCE.md](./REFERENCE.md).

## Files

### Basic Call Handling
| File | Access | Description |
|------|--------|-------------|
| `incoming-call.js` | Public | Handles incoming voice calls with a greeting and gathers user input |
| `gather-input.protected.js` | Protected | Processes gathered DTMF or speech input from incoming calls |

### IVR / Self-Service
| File | Access | Description |
|------|--------|-------------|
| `ivr-welcome.js` | Public | Welcome handler for a dental office IVR self-service menu |
| `ivr-menu.protected.js` | Protected | Routes callers to appointments, billing, or hours based on DTMF/speech |

### Test IVR — GlobalTech Solutions (IVR Crawler Target)
| File | Access | Description |
|------|--------|-------------|
| `test-ivr/welcome.js` | Public | Root language selection (EN/ES/FR) — 20 handlers, 31 terminals |

See [`test-ivr/CLAUDE.md`](./test-ivr/CLAUDE.md) for the full tree structure and file inventory.

### Outbound Contact Center (UC5)
| File | Access | Description |
|------|--------|-------------|
| `outbound-dialer.private.js` | Private | Initiates outbound calls with conference bridge and AMD |
| `outbound-customer-leg.js` | Public | TwiML for the customer leg — starts recording, joins conference |
| `outbound-agent-leg.js` | Public | TwiML for the agent leg — whispers context, joins conference |
| `amd-handler.protected.js` | Protected | Async AMD callback handler — routes machine/human/fax detections via REST API |

### Sales Dialer (UC7)
| File | Access | Description |
|------|--------|-------------|
| `sales-dialer-prospect.js` | Public | TwiML for the prospect leg — starts recording, joins conference |
| `sales-dialer-agent.js` | Public | TwiML for the agent leg — whispers prospect context, joins conference |

### Call Tracking (UC8)
| File | Access | Description |
|------|--------|-------------|
| `call-tracking-inbound.js` | Public | Inbound call tracking with campaign attribution, whisper, and call recording |

### Conference Management
| File | Access | Description |
|------|--------|-------------|
| `create-conference.protected.js` | Protected | Creates a conference and adds the first participant via REST API |
| `add-conference-participant.protected.js` | Protected | Adds a participant to an existing conference |
| `end-conference.protected.js` | Protected | Ends an active conference by updating status to completed |

### Notification / Outbound
| File | Access | Description |
|------|--------|-------------|
| `notification-outbound.js` | Public | Outbound appointment reminder calls with recording and confirmation |
| `notification-confirm.protected.js` | Protected | Processes appointment confirmation/denial via DTMF or speech |

### Voice AI / ConversationRelay
| File | Access | Description |
|------|--------|-------------|
| `pizza-agent-connect.js` | Public | Connects incoming calls to the pizza-ordering AI agent via ConversationRelay |

### SIP Lab
| File | Access | Description |
|------|--------|-------------|
| `sip-customer-inbound.js` | Public | ConversationRelay handler for SIP Lab customer agent — connects to customer WebSocket, starts recording |
| `sip-hostess-inbound.js` | Public | ConversationRelay handler for SIP Lab hostess agent — connects to hostess WebSocket, starts recording |

### Media Streams (UC6)
| File | Access | Description |
|------|--------|-------------|
| `stream-connect.js` | Public | Connects call audio to a WebSocket via bidirectional Media Streams |

### Voice SDK / WebRTC
| File | Access | Description |
|------|--------|-------------|
| `token.js` | Public (auth-gated) | Generates Twilio Voice SDK access tokens (JWTs) with VoiceGrant |
| `sdk-handler.protected.js` | Protected | Routes browser-originated Voice SDK calls to PSTN or other clients |

`token.js` is public (not `.protected`) because browser clients cannot generate Twilio request signatures. Auth is enforced via `TOKEN_API_KEY` — callers must pass a matching `apiKey` parameter. The endpoint returns 403 if `TOKEN_API_KEY` is not configured.

### Test Utilities
| File | Access | Description |
|------|--------|-------------|
| `stay-on-line.js` | Public | Keeps a call alive for conference testing — plays a looping message for up to 10 minutes |

## TwiML Voice Verbs

Common verbs: `<Say>`, `<Play>`, `<Gather>`, `<Dial>`, `<Record>`, `<Conference>`, `<Hangup>`, `<Redirect>`, `<Pause>`.

Background nouns (via `<Start>`): `<Stream>`, `<Recording>`, `<Siprec>`, `<Transcription>`.

For detailed options, see [REFERENCE.md](./REFERENCE.md).

## Voice Webhook Parameters

| Parameter | Description |
|-----------|-------------|
| `CallSid` | Unique identifier for the call |
| `AccountSid` | Your Twilio Account SID |
| `From` | Caller's phone number (E.164) |
| `To` | Called phone number (E.164) |
| `CallStatus` | Current call status |
| `Direction` | `inbound` or `outbound-api` |
| `CallerName` | Caller name (if available) |
| `FromCity` | Caller's city |
| `FromState` | Caller's state |
| `FromCountry` | Caller's country |

Gather callbacks include: `Digits` (DTMF), `SpeechResult` (transcribed), `Confidence` (0-1).

## TwiML Control Model

**Critical**: In almost all cases, only ONE TwiML document controls a call at any given time.

**Exception — Background Operations**: Some verbs fork off and continue running while the call executes other TwiML:
- `<Start><Stream>` — Media streaming continues
- `<Start><Recording>` — Recording continues until explicitly stopped
- `<Start><Siprec>` — SIPREC streaming continues
- `<Start><Transcription>` — Real-time transcription continues, delivers events via webhook

**Key Implications**:
1. Updating participant TwiML exits current state (e.g., exits conference)
2. Conference teardown risk if exiting participant has `endConferenceOnExit=true`
3. "Transfer" in conference context means adding a participant, NOT replacing TwiML

## Logging and Response Rules

| Log Level | Alert Code | Effect |
|-----------|------------|--------|
| `console.log` | None | Silent — use for all operational logging |
| `console.warn` | 82004 | Generates warning alert — **never use** |
| `console.error` | 82005 | Generates error alert — **never use** |

Always pass a string to `response.setBody()`, not an object. Use `JSON.stringify()` and set `Content-Type: application/json`.

### `<Start><Transcription>` Callbacks Are Form-Encoded

Transcription status callbacks (`transcription-started`, `transcription-content`, `transcription-stopped`, `transcription-error`) arrive as `application/x-www-form-urlencoded`, not JSON. Parse with `event.TranscriptionText`, `event.TranscriptionSid`, etc. — not `JSON.parse(event.body)`.

## Gotchas

### Env Vars Can Reset on Deploy

`twilio serverless:deploy` doesn't preserve runtime env vars set via Console or CLI. Verify and re-set after deployment.

### `<Start><Recording>` Syntax is `.recording()`, Not `.record()`

The correct syntax is `twiml.start().recording({...})`. Using `.record()` is a different verb (`<Record>`).

### Conference Has No Parent/Child Relationships

Each conference participant is independent. One disconnecting doesn't affect others unless `endConferenceOnExit=true`. Different from `<Dial>` where parent/child are coupled.

### `<Pause>` as First TwiML Verb Does Not Answer

A webhook returning `<Pause>` as the first verb never answers the call — it continues ringing. Always produce audio (`<Say>` or `<Play>`) first.

### `<Record>` Without `action` Creates Infinite Loop

`<Record>` without `action` POSTs back to self, re-executing and creating multiple recordings. Always set `action` to a different handler or use `<Start><Recording>` instead.

### Conference Recording via Participants API

Do NOT use `client.conferences(name).recordings.create()` with friendly names — it fails. Instead, set `conferenceRecord: 'record-from-start'` on the participant create call.

### Conference Participants API vs TwiML `<Conference>`

| Parameter | Participants API | TwiML |
|-----------|-----------------|-------|
| Recording | Boolean: `true` / `false` | String: `record-from-start`, `record-from-answer`, etc. |

Passing TwiML values to API returns HTTP 400.

### Recording Callback URLs Must Be Absolute

`<Start><Recording>` requires absolute URLs. Relative paths trigger error 11200 — recording completes but callback never fires.

Note: `<Gather action>` and `<Dial action>` resolve relative URLs correctly. This inconsistency only affects `<Start><Recording>`.

### Dial `action` URL Should Not Be the Inbound Handler

When `<Dial action="/voice/my-handler">` is set, the handler fires again after Dial completes. One-time resource creation (e.g., Sync documents) produces "Unique name already exists" errors (54302). Use a dedicated Dial-complete handler or make creation idempotent.

### Deployment Resets Phone Number Webhooks

`twilio serverless:deploy` can reset phone number voice URLs to previous values. Always verify and re-set after deployment.

### Conference Recording Captures Hold Music

When using `Record=true` on Participants API, recording starts from conference creation. If AMD classification takes time, recording captures minutes of hold music and transcripts get dominated by `[music]` tags.

### Avoid Duplicate Recordings

Don't combine `--record` CLI flag (or `Record=true` API param) with `<Start><Recording>` TwiML — creates two recordings (1-channel vs 2-channel). Pick one method.

### Participants API to Twilio Numbers Invokes the Voice URL

The Participants API does NOT auto-generate conference TwiML. When adding a Twilio number as participant, that number's voice URL fires and must return conference-joining TwiML. Conference name is NOT in webhook params — use `make_call` with `?ConferenceName=X` query param instead.

### `make_call(To=TwilioNumber)` Creates Two Independent TwiML Legs

When `make_call` targets a Twilio number, two separate call legs execute independently:
- **Parent leg** (outbound-api): Runs the `Url` parameter's TwiML
- **Child leg** (inbound): Runs the number's configured voice webhook TwiML

Both execute simultaneously and are bridged. A single `make_call` produces TWO TwiML documents on TWO call SIDs. For conference patterns, call each participant separately with their own `Url` TwiML.

### Testing Outbound Calls to Twilio Numbers

When calling TO a Twilio number for testing, that number's voice webhook fires for the child leg. If the destination number has no voice URL configured (or it's empty), the call fails silently. Deploy a "stay-on-line" function and configure it as the voice URL on test destination numbers.

### Pre-E2E: Verify ALL Phone Numbers Have Voice URLs

Before E2E tests, verify every phone number in the call flow has a voice URL — not just inbound/tracking numbers, but Dial destinations, agent numbers, and business lines. A number with `voiceUrl: null` causes `<Dial>` to fail immediately with no useful error.

## File Naming Conventions

- `*.js` — Public endpoints (no signature validation)
- `*.protected.js` — Protected endpoints (require valid Twilio signature)
- `*.private.js` — Private functions (not accessible via HTTP)
