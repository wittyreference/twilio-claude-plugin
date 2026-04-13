---
name: "conference"
description: "Twilio development skill: conference"
---

---
name: conference
description: Twilio Conference development guide. Use when building call orchestration with hold/mute, warm transfers, coaching/whisper/barge, or any call flow needing Conference or Participants API.
allowed-tools: mcp__twilio__*, Read, Grep, Glob
---

# Conference Development Skill

Comprehensive decision-making guide for Twilio Conference. Load this skill when building call flows that need hold, mute, warm transfer, coaching, or any multi-party orchestration.

> **WARNING: Conference REST API state can be misleading.** The REST API may report a conference as `in-progress` with participants `muted: false` when audio is actually muted (all participants have `startConferenceOnEnter=false`). Do not trust API state alone for audio-level verification. Use Conference Insights for authoritative post-call state. See Gotcha #2.

**Evidence date**: 2026-03-24 | **Account**: ACxx...xx | **Intelligence Service**: GA7d01ec... (conference-validation)

## What Conference Cannot Do

Explicit list of things developers commonly assume work but don't:

- **Cannot use `<Gather>` inside a conference** — DTMF goes into the audio mix, not a handler
- **Cannot rely on speaker events for app logic** — fire too frequently to be actionable
- **Cannot get post-flight participant data from REST API** — completed conferences return empty; Insights is the only source
- **Cannot verify coaching via conference recording** — coach audio is NOT in the conference mix recording; only REST API and Insights events confirm coaching [Evidence: GT6e8b15..., 2026-03-24]
- **Cannot filter Insights list endpoint by `processing_state`** — must fetch by SID directly
- **Cannot use PII in friendlyName** — compliance requirement, not just a suggestion
- **Cannot create a conference with 0 call legs and get Insights data** — Insights requires ≥1 participant call attempt
- **Cannot poll Insights immediately after conference end** — takes 15-30+ minutes even for `in_progress` state
- **Cannot do CRM screen pops** — Conference provides call events; displaying caller context in a CRM is your application's JavaScript (Voice SDK call event → extract caller info → open CRM URL). Flex has built-in CRM panels; custom contact centers must build this.
- **Cannot compute EWT** — Conference and TaskRouter provide queue statistics but not Estimated Wait Time calculations or announcements. You must poll queue stats, compute estimates, and serve them via a custom `waitUrl` handler.

## What Conference Actually Is

Conference is primarily a **2-party call orchestration primitive**, not a meeting room. Despite supporting up to 250 participants:

| Usage | Frequency | Purpose |
|-------|-----------|---------|
| 2-party orchestration | ~95% | Hold, mute, recording control on a simple call |
| 3-party calls | ~5% | Warm transfer, coach/whisper/barge |
| True multi-party | Rare | Conference calls with 4+ participants |

Developers choose Conference over `<Dial>` to gain programmatic control over each participant independently — muting, holding, adding/removing participants, and recording — capabilities `<Dial>` does not provide.

### Architecture

- **Two creation methods**: TwiML `<Dial><Conference>` (inbound callers join a named room) vs Participants REST API (outbound, programmatic control). Can mix both.
- **Lifecycle**: `init` → `in-progress` → `completed` (terminal, never reactivated)
- **One in-progress conference per friendlyName** at a time. Multiple completed conferences can share the same name.
- **Startup requirement**: Needs ≥2 participants, with at least one having `startConferenceOnEnter=true`. A single participant with `startConferenceOnEnter=false` waits indefinitely hearing hold music.

### Termination

| `reasonConferenceEnded` | Trigger |
|-------------------------|---------|
| `conference-ended-via-api` | POST with `Status=completed` |
| `participant-with-end-conference-on-exit-left` | Participant with `endConferenceOnExit=true` hung up |
| `participant-with-end-conference-on-exit-kicked` | That participant was removed via API |
| `last-participant-kicked` | Final participant removed via DELETE |
| `last-participant-left` | Final participant hung up |

The `callSidEndingConference` property records which Call SID triggered termination.

## When to Use Conference (and When Not To)

### Use Conference When

- **Hold/mute/resume** on a 2-party call — Conference is the only way to hold one party while keeping the call alive
- **Warm transfer** — Adding a third party requires Conference; `<Dial>` can't do 3-way
- **Coach/whisper/barge** — Supervisor monitoring with selective audio routing
- **Mid-call recording control** — Start/stop/pause recording per participant or conference-wide
- **Programmatic participant management** — Add, remove, mute, hold participants via API without TwiML changes

### Use `<Dial>` Instead When

- **Simple A→B forwarding** — No hold, mute, or transfer needed
- **Parent/child call model is helpful** — `<Dial>` fires an `action` URL when the dialed party disconnects, letting you handle post-call logic (voicemail, survey). Conference has no parent/child relationship.
- **Simpler mental model** — One call dials another. No conference naming, no participant management.
- **Cost sensitivity** — `<Dial>` has no additional per-participant-per-minute charge

### Use Queue Instead When

- **Holding callers for next-available-agent** — `<Enqueue>` + TaskRouter handles queuing natively. Conference is overkill if you just need "wait for agent."
- **No per-participant control during hold** — Queue hold music is simpler than conference waitUrl

### Use TaskRouter Instead When

- **Skills-based routing is the primary need** — TaskRouter handles worker selection; Conference handles the call itself. Often used together (TaskRouter routes, Conference bridges).

### Cost Consideration

Conference adds per-participant-per-minute charges on top of standard voice pricing. For high-volume 2-party calls where you never use hold/mute/transfer, `<Dial>` is cheaper.

## Quick Decision Reference

| Need | Use | Why |
|------|-----|-----|
| 2-party call with hold/mute | Conference | Only way to hold/mute independently |
| Simple call forwarding | `<Dial>` | Simpler, cheaper, has action URL |
| Warm transfer (3-party) | Conference | `<Dial>` can't add third party |
| Coach/whisper/barge | Conference + Participants API | Coaching requires Conference participant model |
| Hold callers for agent | `<Enqueue>` + TaskRouter | Purpose-built for queuing |
| Programmatic recording control | Conference | Start/stop/pause per participant |
| Call with post-disconnect logic | `<Dial>` with action URL | Conference has no parent/child |

## Decision Frameworks

### TwiML `<Conference>` vs Participants API

| Scenario | Use | Why |
|----------|-----|-----|
| Inbound caller joins a named room | TwiML `<Conference>` | Natural fit — caller's webhook returns TwiML |
| Outbound participant added programmatically | Participants API | REST call, no TwiML needed for the join |
| Mixed: inbound + outbound additions | Both | Inbound via TwiML, additions via API |
| Full programmatic control (contact center) | Participants API for all | Create conference by adding first participant |

### Conference Naming Strategy

- **Use customer CallSid as friendlyName** for 1:1 support conferences — guaranteed unique per call
- **Use descriptive prefixes** for fleet management: `conf-{timestamp}-{random}`, `support-{callSid}`
- **Never use PII** (phone numbers, names, emails) in friendlyName — compliance requirement
- **Max 128 characters**
- **Only one in-progress conference per name** — reusing a name while one is active merges callers into it

### Hold vs Mute (Critical Distinction)

| | Muted | On Hold |
|---|---|---|
| Can hear conference | **Yes** | No |
| Conference can hear them | No | No |
| Hears hold music | No | **Yes** (if HoldUrl set) |
| Use case | Listener mode, self-mute | Parking a caller, private sidebar |

Getting this wrong is a common source of bugs. Mute ≠ Hold.

### Recording Method Selection

| Method | Scope | Parameter | Notes |
|--------|-------|-----------|-------|
| Conference-level (TwiML) | Whole mix | `record="record-from-start"` | String value, not boolean |
| Conference-level (API) | Whole mix | `ConferenceRecord=true` | Boolean — different from TwiML |
| Per-participant (API) | Single leg | `Record=true` | Boolean |
| Dual-channel | Single leg | `RecordingChannels="dual"` | Separate inbound/outbound tracks |

Do NOT combine conference-level recording with `<Start><Recording>` — you get duplicate recordings.
Conference recording captures hold music — be aware when transcribing.

## Gotchas (Quick Reference)

### Startup

1. **≥2 participants required**: Conference needs at least 2 participants, with at least one having `startConferenceOnEnter=true`, before it starts. A solo participant with `startConferenceOnEnter=false` waits forever hearing hold music.
2. **Startup sequence matters**: If all participants have `startConferenceOnEnter=false`, participants hear hold music and are audio-muted. However, the REST API may show the conference as `in-progress` with participants `muted: false` — the API state does not reliably reflect the audio-level hold/mute behavior of the `startConferenceOnEnter` gate. [Evidence: CFb40284..., 2026-03-24]

### Configuration

3. **Only ONE in-progress conference per friendlyName**: Adding participants to a name with an active conference joins that conference. This is by design but surprises developers who reuse names.
4. **participantLabel must be unique**: Duplicate labels cause error **16025** and the participant will NOT join. Max 128 chars.
5. **No PII in friendlyName**: Compliance requirement — phone numbers, names, emails must never appear in conference names.
6. **friendlyName max 128 chars**: Silently truncated or rejected beyond this.
7. **statusCallbackMethod defaults to POST with waitUrl, GET otherwise**: Inconsistent with typical defaults. Specify explicitly.

### Participant & Call Control

8. **endConferenceOnExit teardown risk**: If a participant with `endConferenceOnExit=true` leaves, the ENTIRE conference ends — appearing as a dropped call to everyone else. The #1 conference bug.
9. **Conference has NO parent/child relationships**: Unlike `<Dial>`, there's no action URL fired when a participant disconnects. Each participant is independent.
10. **Updating participant TwiML exits conference**: Calling `client.calls(participantSid).update({twiml: ...})` immediately removes them from the conference. If they had `endConferenceOnExit=true`, the whole conference tears down.
11. **API participant to Twilio number invokes voice URL**: Adding a Twilio number via Participants API triggers that number's configured voice webhook. The conference name is NOT in webhook params — pass it as a query parameter.
12. **No `<Gather>` inside conference**: Once a participant joins, DTMF goes into the audio mix. Handle DTMF BEFORE joining the conference.

### Recording

13. **API recording param is boolean, TwiML is string**: Participants API uses `Record=true/false`. TwiML uses `record="record-from-start"`. Mixing syntax causes silent failures.
14. **Recording captures hold music**: Conference recording runs continuously. Hold music gets recorded and dominates transcripts.
15. **Don't combine recording methods**: Conference-level recording + `<Start><Recording>` produces duplicate recordings with different SIDs.

### Infrastructure & Observability

16. **1 CPS rate limit for Participants API**: Default is 1 call per second. Up to 30 CPS with approved Business Profile. Plan for this in high-volume scenarios.
17. **waitUrl failure can break conference**: If waitUrl returns an error, conference establishment may fail silently. Always test your waitUrl.
18. **Completed conference returns empty participants**: REST API `GET /Participants` on a completed conference returns nothing. Use Conference Insights for historical participant data — it's the ONLY source.
19. **SID-based creation needs active conference**: Creating a participant with a ConferenceSid (CF...) fails if that conference isn't active. Use FriendlyName to auto-create.
20. **Jitter buffer tradeoffs**: `large` (default, 300-1000ms latency, most resilient), `small` (150-200ms, more artifacts), `off` (zero added latency, drops packets >20ms jitter). Spikes can exceed average by 50%.
21. **Speaker events fire too frequently**: Conference speaker status callback events fire at very high frequency — nearly useless for application logic. Don't build state machines on them.
22. **Conference recording does NOT capture coaching audio**: The coach's voice is routed only to the coached participant and never enters the conference mixer output. Conference-level recordings are blind to coaching. Use REST API state and Insights events to verify coaching behavior. [Evidence: GT6e8b15..., Intelligence analysis detected only 2 voices in 3-party coaching conference]

### Parallel Dial Rate Limits

The Calls API has a default rate of 1 call per second (CPS). When implementing parallel dialing (e.g., calling 3 prospects simultaneously per rep):
- `Promise.all()` with 3+ `calls.create()` may be throttled at default CPS
- Use `batchWithRateLimit()` from `helpers/resilience-patterns.private.js` or stagger calls by 1s
- Request CPS increase via Twilio support for production dialers

### Excess Call Cancellation in Parallel Dial

When multiple prospects are called in parallel and the first answers:
- The application MUST cancel remaining in-flight calls via `calls(callSid).update({ status: 'canceled' })`
- Calls in `ringing` or `queued` status can be canceled; `in-progress` calls need `status: 'completed'`
- Use the AMD callback to trigger cancellation: when one prospect is confirmed human, cancel the rest
- Without cancellation, abandoned calls ring to voicemail, wasting resources and potentially triggering spam flags

- **Consistent authentication across Functions**: If some Functions in your deployment use Account SID + Auth Token (`new Twilio(accountSid, authToken)`) while others use API Key auth (`new Twilio(apiKey, apiSecret, { accountSid })`), verify that all credential pairs belong to the same account. Mixing main-account auth tokens with sub-account API keys (or vice versa) causes 401 errors on some operations while others succeed — creating confusing partial failures. Standardize on one authentication method across all Functions in a deployment.

## Cascade Chains

### Outbound Campaign: AMD + Agent Partition

```
Outbound call initiated with AMD
  → AMD detects human (async callback)
    → System creates conference, adds customer
      → System attempts to bridge agent
        → Agent's browser/network is down
          → Customer in conference alone (silence)
            → No endConferenceOnExit on agent (never joined) → conference persists
              → Customer hears silence until they hang up
```

**Detection**: After adding customer to conference, poll `list_conference_participants`. If participant count is 1 after N seconds (agent join timeout), the agent failed to connect.

**Mitigation**:
1. **Agent connectivity pre-check**: Before dialing the customer, verify agent's WebSocket/browser session is active. If agent went offline between campaign start and AMD callback, skip the bridge.
2. **Conference participant timeout**: After adding the customer, start a timer. If the agent hasn't joined within 10 seconds, play an apology message to the customer and disconnect them gracefully. Use `update_conference_participant` to play a `announceUrl` before removing.
3. **Fallback TwiML**: Set the customer's `endConferenceOnExit=true` so if they hang up, the empty conference cleans up. Set the agent's `endConferenceOnExit=false` so if the agent drops, the customer isn't immediately disconnected (giving time for the failover to engage).

## Related Resources

- **Voice skill** — Conference vs Dial decision framework, broader voice context
- **Voice CLAUDE.md** (`CLAUDE.md`) — TwiML control model, conference function inventory, coding-level gotchas
- **Voice REFERENCE.md** (`REFERENCE.md`) — Conference REST API code patterns, safe transfer pattern
- **Voice Use Case Map** — UC 3 (Contact Center), UC 4 (Warm Transfer), UC 7 (Coaching) all use Conference
- **Conference MCP Tools**: `list_conferences`, `get_conference`, `update_conference`, `list_conference_participants`, `get_conference_participant`, `update_conference_participant`, `add_participant_to_conference`, `list_conference_recordings`, `get_conference_summary`, `list_conference_participant_summaries`, `get_conference_participant_summary`
- **Codebase functions**: `create-conference.protected.js`, `add-conference-participant.protected.js`, `end-conference.protected.js`, `outbound-dialer.private.js`, `outbound-customer-leg.js`, `outbound-agent-leg.js`, `sales-dialer-prospect.js`, `sales-dialer-agent.js`

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| Call flow patterns | `references/patterns.md` | Building warm transfer, moderated conferences, outbound dialer, sales dialer |
| Participant management | `references/participant-management.md` | Coach/whisper/barge, hold/mute, DTMF, dynamic control, API parameters |
| Insights & validation | `references/insights-and-validation.md` | Conference Insights, quality thresholds, debugging, validation checklists |
| Test results | `references/test-results.md` | Live test evidence with SID matrix, Intelligence analysis |
| Assertion audit | `references/assertion-audit.md` | Adversarial audit of every factual claim with verdicts |
| RTT interaction | `references/rtt-interaction.md` | Using Real-Time Transcription on conference calls — track semantics, hold behavior, capture conflicts |
