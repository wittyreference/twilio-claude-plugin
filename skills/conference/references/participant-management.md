---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Conference participant lifecycle management via the Participants REST API. -->
<!-- ABOUTME: Covers coach/whisper/barge mechanics, hold/mute, DTMF, rate limits, and regional hosting. -->

# Participant Management

## Participants API Create Parameters

### Required

| Parameter | Description |
|-----------|-------------|
| `From` | Originating number (E.164), Client ID (`client:name`), or SIP username |
| `To` | Destination phone, client, or SIP address |

### Conference Behavior

| Parameter | Default | Description |
|-----------|---------|-------------|
| `StartConferenceOnEnter` | `true` | Conference begins when this participant joins |
| `EndConferenceOnExit` | `false` | Conference ends when this participant leaves |
| `MaxParticipants` | 250 | Conference size limit (1-250) |
| `Beep` | `true` | Play beep on join (`true`/`false`/`onEnter`/`onExit`) |
| `Muted` | `false` | Start participant muted |
| `Label` | none | Unique identifier (max 128 chars, error 16025 if duplicate) |

### Call Control

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Timeout` | 30 | Seconds to wait for answer |
| `TimeLimit` | 14400 | Maximum call duration (seconds) |
| `EarlyMedia` | `false` | Play early media before connection |
| `CallerId` | none | Caller ID presentation |
| `CallReason` | none | Reason for call (max 255 chars, SIP `X-]PH-Call-Reason` header) |

### Audio

| Parameter | Description |
|-----------|-------------|
| `WaitUrl` | TwiML for hold music/announcements before conference starts |
| `WaitMethod` | `GET` or `POST` |
| `JitterBufferSize` | `small`, `medium`, `large` (default), `off` |
| `RecordingChannels` | `mono` (default) or `dual` (separate inbound/outbound) |
| `RecordingTrack` | `inbound`, `outbound`, or `both` |

### Coaching

| Parameter | Description |
|-----------|-------------|
| `Coaching` | `true`/`false` — enable coaching mode |
| `CallSidToCoach` | Target Call SID for coaching |

### Recording

| Parameter | Description |
|-----------|-------------|
| `Record` | `true`/`false` — record this call leg (boolean, NOT string like TwiML) |
| `ConferenceRecord` | `true`/`false`/`adaptive` — record the conference mix |
| `ConferenceTrim` | `trim-silence` to remove silence periods |

### Callbacks

| Parameter | Description |
|-----------|-------------|
| `StatusCallback` | URL for call status updates |
| `StatusCallbackEvent` | `initiated`, `ringing`, `answered`, `completed` |
| `StatusCallbackMethod` | `GET` or `POST` |
| `ConferenceStatusCallback` | URL for conference events |
| `ConferenceStatusCallbackMethod` | `GET` or `POST` |
| `ConferenceStatusCallbackEvent` | `join`, `leave`, `mute`, `hold`, `speaker` |
| `RecordingStatusCallback` | Call-leg recording notification URL |
| `RecordingStatusCallbackMethod` | `GET` or `POST` |
| `ConferenceRecordingStatusCallback` | Conference recording notification URL |
| `ConferenceRecordingStatusCallbackMethod` | `GET` or `POST` |
| `ConferenceRecordingStatusCallbackEvent` | Recording events |

### SIP

| Parameter | Description |
|-----------|-------------|
| `SipAuthUsername` | SIP authentication username |
| `SipAuthPassword` | SIP authentication password |
| `Region` | Geographic region for the call leg |
| `ConferenceRegion` | Conference server region (can differ from call Region) |
| `Byoc` | Bring Your Own Carrier trunk SID |

### Answering Machine Detection (AMD)

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MachineDetection` | none | `Enable`, `DetectMessageEnd`, `DetectSpeechEnd` |
| `MachineDetectionTimeout` | 5000ms | Max analysis time |
| `MachineDetectionSpeechThreshold` | 2400ms | Voice activity threshold |
| `MachineDetectionSpeechEndThreshold` | 1200ms | End-of-speech detection |
| `MachineDetectionSilenceTimeout` | 1200ms | Silence before decision |
| `AmdStatusCallback` | none | Callback for AMD result |
| `AmdStatusCallbackMethod` | none | `GET` or `POST` |

## Participants API Update Parameters

| Parameter | Description |
|-----------|-------------|
| `Muted` | `true`/`false` — mute or unmute |
| `Hold` | `true`/`false` — place on or take off hold |
| `HoldUrl` | TwiML URL for hold state audio |
| `HoldMethod` | `GET` or `POST` |
| `AnnounceUrl` | TwiML URL for announcement to this participant only |
| `AnnounceMethod` | `GET` or `POST` |
| `WaitUrl` | Updated hold music URL |
| `WaitMethod` | `GET` or `POST` |
| `BeepOnExit` | `true`/`false` — play beep when this participant leaves |
| `EndConferenceOnExit` | Change exit behavior dynamically |
| `Coaching` | `true`/`false` — enable/disable coaching |
| `CallSidToCoach` | Change or set coaching target |

## Coach / Whisper / Barge Mechanics

### How Coaching Works

1. Supervisor joins conference with `Coaching=true`, `CallSidToCoach=<agentCallSid>`
2. **Supervisor hears ALL conference audio** (full mix)
3. **Only the coached participant** (agent) hears the supervisor's voice
4. All other participants hear nothing from the supervisor

This creates a "whisper" effect: the supervisor can guide the agent without the customer hearing.

### Barge (Let Everyone Hear)

Update the supervisor's participant: set `Coaching=false`. The supervisor's audio now goes to the full conference mix — everyone can hear them.

### Retarget Coaching

Update the supervisor's participant with a new `CallSidToCoach` value. Coaching switches to the new target dynamically.

### Coaching Lifecycle

| Action | API Call | Effect |
|--------|----------|--------|
| Start whisper | Create participant with `Coaching=true, CallSidToCoach=X` | Supervisor hears all, only X hears supervisor |
| Barge in | Update participant: `Coaching=false` | Supervisor audio goes to full mix |
| Switch target | Update participant: `CallSidToCoach=Y` | Now coaching Y instead of X |
| Stop coaching | Update participant: `Coaching=false` | Supervisor becomes normal participant |

### Coaching Events (tracked by Insights)

- `Coaching` (started)
- `Coaching stopped`
- `Coaching modified` (target changed)

## Hold Management

Setting `Hold=true` on a participant:
- **Isolates them** from conference audio entirely
- They hear `HoldUrl` audio (or silence if none specified)
- Other participants cannot hear the held participant
- The held participant cannot hear the conference

### Custom Hold Music

Point `HoldUrl` to a TwiML endpoint that returns `<Play loop="0">` for continuous music. The standard `waitUrl` does NOT auto-loop — participants hear silence after the TwiML finishes unless you use `<Play loop="0">` or `<Redirect>` to restart.

### Hold Events

- `hold` — participant placed on hold
- `unhold` — participant taken off hold (via `Hold=false`)

## Announce

`AnnounceUrl` plays audio to a **specific participant only**, not the whole conference.

The URL must return TwiML with `<Say>` or `<Play>`.

Use cases:
- "You are being recorded" (compliance)
- "Agent joining shortly" (customer notification)
- "Caller has been waiting 5 minutes" (agent notification)
- Custom beep replacement

## DTMF in Conferences

- Once a participant joins a conference, there is **no `<Gather>`** mechanism
- DTMF tones are transmitted as audio in the conference mix (other participants hear the tones)
- Handle DTMF **before** joining the conference (e.g., IVR menu → then join)
- For conference-level DTMF detection, use `eventCallbackUrl` — but this is limited

### Workaround for Mid-Conference DTMF

If you need DTMF input during a conference (e.g., "press 1 to leave"), the only option is to remove the participant from the conference, gather their input via TwiML, then add them back. This is disruptive and rarely worth it.

## Rate Limits

| Method | Default Limit | With Business Profile |
|--------|--------------|----------------------|
| Participants API (POST) | **1 CPS** | Up to 30 CPS |
| `<Dial><Conference>` (TwiML) | Not rate-limited | N/A |

For high-volume conference creation (e.g., sales dialer creating 100+ conferences/minute), plan around the 1 CPS limit. Options:
- Apply for increased CPS via Business Profile in Twilio Console
- Use TwiML `<Conference>` for inbound legs (not rate-limited) + API for additions
- Spread outbound creation across time windows

Non-Twilio numbers in `From` must be verified as Outgoing Caller IDs.

## Regional Hosting

### Available Regions

| Code | Location |
|------|----------|
| `us1` | United States |
| `us2` | United States (alternate) |
| `ie1` | Ireland |
| `de1` | Germany |
| `sg1` | Singapore |
| `br1` | Brazil |
| `au1` | Australia |
| `jp1` | Japan |

### Region Selection

- Defaults to nearest region if not specified
- `ConferenceRegion` (where the conference mixer runs) can differ from `Region` (where the call leg routes)
- **Region mismatch** between participant media entry and conference mixer is flagged as a quality issue in Conference Insights
- **Best practice**: co-locate conference region with the majority of participants to minimize latency
- For global conferences, choose a central region or accept latency tradeoffs
