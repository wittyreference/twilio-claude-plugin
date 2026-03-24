---
name: conference
description: Twilio Conference development guide. Use when building call orchestration with hold/mute, warm transfers, coaching/whisper/barge, or any call flow needing Conference or Participants API.
---

# Conference Development Skill

Comprehensive decision-making guide for Twilio Conference. Load this skill when building call flows that need hold, mute, warm transfer, coaching, or any multi-party orchestration.

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
2. **Startup sequence matters**: If all participants have `startConferenceOnEnter=false`, the conference stays in `init` permanently.

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

## Related Resources

- **Voice skill** — Conference vs Dial decision framework, broader voice context
- **Voice Use Case Map** — UC 3 (Contact Center), UC 4 (Warm Transfer), UC 7 (Coaching) all use Conference
- **Conference MCP Tools**: `list_conferences`, `get_conference`, `update_conference`, `list_conference_participants`, `get_conference_participant`, `update_conference_participant`, `add_participant_to_conference`, `list_conference_recordings`, `get_conference_summary`, `list_conference_participant_summaries`, `get_conference_participant_summary`

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| Call flow patterns | `references/patterns.md` | Building warm transfer, moderated conferences, outbound dialer, sales dialer |
| Participant management | `references/participant-management.md` | Coach/whisper/barge, hold/mute, DTMF, dynamic control, API parameters |
| Insights & validation | `references/insights-and-validation.md` | Conference Insights, quality thresholds, debugging, validation checklists |
