<!-- ABOUTME: Conference call flow patterns including warm transfer, moderated conferences, and outbound dialer. -->
<!-- ABOUTME: Contains startOnEnter/endOnExit configuration tables and TwiML attribute reference. -->

# Conference Patterns

## 2-Party Call Orchestration (The Common Case)

The most common conference usage: two participants bridged via Conference to gain hold/mute/recording control that `<Dial>` doesn't provide.

**Setup**: Create conference by adding the first participant via Participants API, then add the second. Both have `startConferenceOnEnter=true`. The first participant hears hold music briefly until the second joins.

**Key config for 2-party**:

| Participant | startConferenceOnEnter | endConferenceOnExit | Why |
|-------------|----------------------|---------------------|-----|
| Party A | `true` | `true` | Either party hanging up ends the call |
| Party B | `true` | `true` | Symmetric — both can end |

## Warm Transfer Pattern

The #1 reason developers move from 2-party to 3-party. Customer talks to Agent1, Agent1 brings in Agent2, Agent1 drops off.

### Sequence

1. **Customer + Agent1** are in a 2-party conference
2. **Agent1 initiates transfer** by adding Agent2 to the conference
3. **All three talk** (optional consultation phase)
4. **Agent1 drops** — conference continues with Customer + Agent2
5. **Customer or Agent2 hangs up** — conference ends

### Configuration

| Participant | startConferenceOnEnter | endConferenceOnExit | Rationale |
|-------------|----------------------|---------------------|-----------|
| Customer | `true` (or `false` if waiting) | `true` | Ends conf on hangup |
| Agent 1 (transferring) | `true` | **`false`** | Can leave without ending conf |
| Agent 2 (receiving) | `true` | `true` | Ends conf on hangup |

The critical setting is Agent1's `endConferenceOnExit=false`. Without it, Agent1 hanging up kills the entire conference.

### Conference ID Strategy for Warm Transfer

Use the customer's Call SID as the conference FriendlyName: guaranteed unique per call, easy to correlate in logs.

## Moderated Conference Pattern

Moderator-gated start: participants join and wait with hold music until the moderator arrives.

### Configuration

| Participant | startConferenceOnEnter | endConferenceOnExit | Behavior |
|-------------|----------------------|---------------------|----------|
| Moderator | `true` | `true` | Starts conf, ends it on leave |
| All others | `false` | `false` | Wait with hold music until moderator joins |

### Sequence

1. Participants join first — muted, hearing hold music (conference in `init`)
2. Moderator joins — conference transitions to `in-progress`, participants unmuted
3. Moderator leaves — conference ends (all others disconnected)

Use case: briefings, scheduled group calls, webinar-style voice sessions.

## Outbound Contact Center Pattern

Agent-initiated outbound calls using conference as the bridge. AMD (Answering Machine Detection) screens for voicemail before connecting the agent.

### Sequence

1. **Dialer creates conference** with unique name (`outbound-{timestamp}-{random}`)
2. **Customer called first** with AMD enabled
3. **On human detection** → agent added to conference
4. **Agent hears whisper** (brief announcement) before conference audio
5. **Both parties in conference** — full hold/mute/transfer available

### Key Settings

- Customer: `startConferenceOnEnter=true`, `endConferenceOnExit=true`
- Agent: `startConferenceOnEnter=true`, `endConferenceOnExit=false`
- AMD: `MachineDetection=Enable` on customer's Participants API call

## Sales Dialer Pattern

Variant of the outbound contact center pattern optimized for high-volume prospecting.

- Prospect called with conference recording from start (`record: 'record-from-start'`)
- Agent joins the same conference
- Status callbacks track call outcomes

## Safe vs Dangerous Transfer

### Safe: Add Participant to Conference

Everyone stays connected. The new party joins the existing mix.

```
// Agent wants to bring in specialist
// → Add specialist to existing conference (nobody leaves)
// → All three parties now connected
// → Agent can drop off by having their participant removed
```

### Dangerous: Update Call TwiML

Updating a participant's call with new TwiML (via `client.calls(sid).update({twiml: ...})`) **immediately removes them from the conference**. If that participant had `endConferenceOnExit=true`, the entire conference tears down — appearing as a dropped call to everyone else.

**Rule**: In a conference context, "transfer" means adding a new participant, never replacing TwiML.

## Conference ID Strategy

| Strategy | When to use | Example |
|----------|-------------|---------|
| Customer CallSid | 1:1 support calls | `CA1234567890abcdef...` |
| Descriptive prefix + random | Fleet management | `outbound-1711234567-a3f2` |
| Timestamp + random | General uniqueness | `conf-1711234567-x7k9` |
| Semantic name | Scheduled/recurring | `standup-2024-03-24` |

**Never use PII** (phone numbers, names) in conference names. Compliance requirement.

## TwiML `<Conference>` Attributes (Full Reference)

### Core Participant Behavior

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `muted` | boolean | `false` | Participant can listen but cannot speak |
| `beep` | `true`/`false`/`onEnter`/`onExit` | `true` | Sound on join/leave events |
| `startConferenceOnEnter` | boolean | `true` | Conference begins when this participant joins |
| `endConferenceOnExit` | boolean | `false` | Conference terminates when this participant leaves |
| `participantLabel` | string | none | Unique ID for REST API operations (max 128 chars, error 16025 if duplicate) |
| `maxParticipants` | integer | 250 | Maximum allowed (1-250) |
| `coach` | Call SID | none | Enable coaching for the specified call |

### Audio & Media

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `jitterBufferSize` | enum | `large` | `small` (150-200ms), `medium` (200-360ms), `large` (300-1000ms), `off` (drops packets >20ms jitter) |
| `record` | enum | `do-not-record` | `do-not-record` or `record-from-start` (string, NOT boolean) |
| `trim` | enum | `trim-silence` | `trim-silence` or `do-not-trim` |
| `region` | enum | auto | `us1`, `us2`, `ie1`, `de1`, `sg1`, `br1`, `au1`, `jp1` |

### Hold Music / Wait URL

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `waitUrl` | URL | Twilio classical playlist | TwiML/media played before conference starts |
| `waitMethod` | `GET`/`POST` | `POST` | HTTP method for waitUrl |

**Supported TwiML verbs in waitUrl**: `<Play>`, `<Say>`, `<Pause>`, `<Redirect>`

**Built-in playlists** (via twimlets.com holdmusic with `Bucket` parameter):
- `com.twilio.music.classical` (default)
- `com.twilio.music.ambient`
- `com.twilio.music.electronica`
- `com.twilio.music.guitars`
- `com.twilio.music.rock`
- `com.twilio.music.soft-rock`

Set `waitUrl=""` (empty string) for **complete silence**.

### Status Callbacks

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `statusCallback` | URL | none | Webhook for conference state changes |
| `statusCallbackMethod` | `GET`/`POST` | `POST` if waitUrl set, else `GET` | HTTP method (inconsistent default — specify explicitly) |
| `statusCallbackEvent` | space-separated | none | Events: `start`, `end`, `join`, `leave`, `mute`, `hold`, `modify`, `speaker`, `announcement` |
| `eventCallbackUrl` | URL | none | Real-time participant events (separate from statusCallback) |

**Warning**: `speaker` events fire at very high frequency — nearly useless for application logic.

### Recording Callbacks

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `recordingStatusCallback` | URL | none | Recording-specific webhook |
| `recordingStatusCallbackMethod` | `GET`/`POST` | `POST` | HTTP method |
| `recordingStatusCallbackEvent` | enum | `completed` | `in-progress`, `completed`, `absent` |
