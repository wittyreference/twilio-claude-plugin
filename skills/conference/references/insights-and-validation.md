<!-- ABOUTME: Conference Insights API reference and validation checklists for conference implementations. -->
<!-- ABOUTME: Covers quality thresholds, post-flight participant data, and systematic debugging workflows. -->

# Conference Insights & Validation

## Why Conference Insights Is Critical

Conference Insights is **non-negotiable** for anyone doing Conference at scale. Here's why:

**The REST API returns empty participants for completed conferences.** Once a conference ends, `GET /Conferences/{sid}/Participants` returns nothing. Conference Insights is the **only source** for post-flight participant records — who was in the call, when they joined/left, and what the audio quality looked like.

### Data Retention & Generation

- Conference Insights data available for **30 days** after conference completion
- After 30 days, data is permanently deleted
- Export or aggregate what you need within this window
- **Insights requires at least one call leg**: Conferences created and ended via the REST API without any Participants API call produce no Insights data (API returns 404). Even a single `canceled` participant call is enough — Insights tracks the attempt. But a conference with zero participant call legs has no Insights record.
- **Voice Insights Advanced Features** must be active on the account for API access

## Insights Timing

| `processing_state` | Meaning | Timing |
|--------------------|---------|--------|
| `in_progress` | Data still being aggregated | Variable — can take 15-30+ minutes even for initial appearance |
| `complete` | All aggregations and analysis finished | Up to 30 minutes after conference end |
| `timeout` | System couldn't process within 24 hours | Rare — indicates a system issue |

**Do not poll immediately.** In live testing, Insights records took 15-30+ minutes to appear via the REST API — even the `in_progress` state. The "within minutes" claim in Twilio docs is aspirational, not guaranteed. For faster access, use Event Streams (see below).

Data with `processing_state: in_progress` includes participant list, basic timing, and tags. Quality metrics (jitter, latency, MOS) are finalized when state reaches `complete`. Always check `processing_state` before acting on quality data.

**There is no `processing_state` filter on the list endpoint.** To check a specific conference's state, fetch it by SID directly.

### Event Streams (Fastest Path)

For real-time access faster than REST polling, use Twilio Event Streams:
- `com.twilio.voice.insights.conference-summary.partial` — fires at conference start
- `com.twilio.voice.insights.conference-summary.complete` — fires at conference end
- `com.twilio.voice.insights.participant-summary.complete` — fires at participant leave

## Quality Thresholds

| Metric | Warning Threshold | Description |
|--------|-------------------|-------------|
| **Latency** | ≥ 150ms average | Packet delay from media gateway to mixer |
| **Jitter** | ≥ 5ms average OR ≥ 30ms max | Out-of-order packet arrival variance |
| **Packet Loss** | ≥ 5% cumulative | Monitored in 10-second samples |
| **MOS Score** | ≤ 3.5 | Mean Opinion Score via ITU-T G.107 |

### Issue Detection Categories

**Call Quality Issues**: Network transport metrics affecting audio experience
- High latency, high jitter, packet loss, low MOS

**Participant Behavior Issues**:
- **Silence detection**: No amplitude/frequency data from join to leave. Could be muted mic, broken hardware, or dead air.

**Region Configuration Issues**:
- Geographic mismatch between participant media entry point and conference mixer location. Causes unnecessary latency — often the easiest quality issue to fix.

## Conference Summary API

Use `get_conference_summary` (MCP tool) for aggregate conference data:

- Conference SID, Friendly Name, Start/End time, Duration
- Region (media mixing location)
- Reason Ended + Ended By (call SID or API)
- Participant Count, Max Concurrent Participants
- Processing State (`partial` or `complete`)
- Quality metrics (when `complete`)

### Tracked Timeline Events

- Join / Leave
- Mute / Unmute
- Hold / Unhold
- Beep parameter modifications
- Exit parameter modifications (`endConferenceOnExit` changes)
- Coaching started / stopped / modified

Timeline visualization supports up to **20 participants**. Beyond that, Console shows a participant list instead.

## Participant Summary API

Use `list_conference_participant_summaries` for all participants, or `get_conference_participant_summary` for a specific one.

### Per-Participant Fields

- Participant SID, Call SID
- Call Type: `Carrier`, `SIP`, `Client`
- Media arrival region
- Silent status (boolean)
- Jitter buffer setting
- Average jitter, Max jitter
- Packet loss percentage
- Average latency
- MOS score
- Join/leave timestamps

## Speaker Events Warning

Conference `speaker` status callback events fire at **extremely high frequency** — essentially every time voice activity detection toggles. This makes them nearly useless for application logic like "who is currently talking" tracking.

**Do not**:
- Build state machines on speaker events
- Use speaker events to determine active speaker for UI updates
- Log speaker events to a database (volume will overwhelm storage)

**Instead**: Use Conference Insights post-flight data for speaker analysis, or use client-side audio level detection if you need real-time active speaker.

## Deep Validation Checklist

Mandatory checks for every conference implementation. A 200 OK on conference creation is NOT sufficient.

### Every Conference Implementation

```
[ ] Conference resource — status progressed to 'in-progress', correct participant count
[ ] Each participant — call status 'in-progress', connected to correct conference
[ ] Conference Insights Summary — processingState, participant count matches
[ ] Debugger — no TwiML errors, no HTTP errors on callbacks
[ ] Per-participant call validation — validate_call for each participant leg
```

### When Using Hold/Mute

```
+ [ ] Muted participant — verify muted=true in participant resource
+ [ ] Held participant — verify hold=true, HoldUrl returning valid TwiML
+ [ ] Insights events — mute/unmute/hold/unhold events recorded in timeline
```

### When Using Recording

```
+ [ ] Recording resource — status progressed to 'completed'
+ [ ] Recording method — conference-level OR per-participant, not both
+ [ ] Hold music contamination — check if hold periods are in recording
+ [ ] Dual-channel — if used, verify separate tracks exist
```

### When Using Coaching

```
+ [ ] Coach participant — coaching=true, callSidToCoach set
+ [ ] Insights events — Coaching/Coaching stopped/Coaching modified events
+ [ ] Audio routing — coach hears all, only coached hears coach
+ [ ] Barge transition — Coaching=false makes coach audible to all
```

### When Using Warm Transfer

```
+ [ ] Agent1 endConferenceOnExit=false — verify before Agent1 drops
+ [ ] Conference survives Agent1 departure — conference still in-progress
+ [ ] reasonConferenceEnded — matches expected trigger (customer/agent2 hangup)
+ [ ] callSidEndingConference — identifies correct participant
```

### Post-Flight (30 minutes after completion)

```
+ [ ] REST API participants — returns empty (expected)
+ [ ] Conference Insights Summary — processingState='complete', quality metrics populated
+ [ ] Participant Summaries — all participants present with quality data
+ [ ] Region mismatch — no warnings (or documented as expected)
```

## MCP Tool Reference

### Building & Managing

| Tool | Use |
|------|-----|
| `add_participant_to_conference` | Add outbound participant to conference |
| `update_conference` | End conference or play announcement |
| `update_conference_participant` | Mute, hold, coach, announce to participant |

### Monitoring (Active Conference)

| Tool | Use |
|------|-----|
| `list_conferences` | Find conferences by status, name, date |
| `get_conference` | Conference details by SID |
| `list_conference_participants` | List active participants (empty after completion) |
| `get_conference_participant` | Single participant state |

### Recording

| Tool | Use |
|------|-----|
| `list_conference_recordings` | Conference recordings by status |

### Debugging & Insights (Post-Flight)

| Tool | Use |
|------|-----|
| `get_conference_summary` | Aggregate quality, reason ended, participant count |
| `list_conference_participant_summaries` | All participant metrics (ONLY source post-completion) |
| `get_conference_participant_summary` | Single participant deep dive |
| `validate_call` | Per-leg call validation (status, notifications, insights) |
| `validate_debugger` | Debugger alerts filtered by resource SID |

### Validation Workflow

1. **During call**: `get_conference` + `list_conference_participants` to verify state
2. **Immediately after** (~2 min): `get_conference_summary` with `processingState=partial` for participant list
3. **Post-flight** (~30 min): `get_conference_summary` + `list_conference_participant_summaries` for full quality data
4. **Per-leg**: `validate_call` on each participant's Call SID for call-level issues
5. **Debugger**: `validate_debugger` filtered by conference SID or participant call SIDs
