---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Complete parameter reference for all 7 Twilio call recording methods. -->
<!-- ABOUTME: Code snippets from codebase, every attribute documented, live-tested. -->

# Recording Methods — Parameter Reference

## 1. `<Record>` Verb (Voicemail-Style)

Records the caller's speech after TwiML executes. Blocks subsequent TwiML until recording ends.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `maxLength` | integer | 3600 | Maximum recording length in seconds |
| `timeout` | integer | 5 | Seconds of silence before ending |
| `finishOnKey` | string | `1234567890*#` | DTMF key to end recording |
| `action` | URL | self | **Always set** — without it, POSTs back to self (infinite loop) |
| `playBeep` | boolean | true | Play beep before recording starts |
| `trim` | string | `trim-silence` | `trim-silence` or `do-not-trim` |
| `transcribe` | boolean | false | Legacy Twilio transcription (deprecated — use Voice Intelligence) |
| `recordingStatusCallback` | URL | — | Webhook for recording status |
| `recordingStatusCallbackEvent` | string | `completed` | Events: `in-progress`, `completed`, `absent` |
| `recordingStatusCallbackMethod` | string | `POST` | HTTP method |

```javascript
// Codebase pattern: voicemail with action URL
twiml.say('Leave a message after the beep.');
twiml.record({
  maxLength: 60,
  action: `https://${context.DOMAIN_NAME}/handle-recording`,
  recordingStatusCallback: `https://${context.DOMAIN_NAME}/callbacks/recording-test-status`,
  recordingStatusCallbackEvent: 'completed',
});
```

## 2. `<Dial record="...">` Attribute

Records during a `<Dial>` verb. Recording starts/stops with the Dial.

| `record` Value | Channels | Starts When |
|---------------|----------|-------------|
| `do-not-record` | — | No recording (default) |
| `record-from-answer` | 1 (mono) | Called party answers |
| `record-from-ringing` | 1 (mono) | Dial starts (includes ringback) |
| `record-from-answer-dual` | 2 | Called party answers |
| `record-from-ringing-dual` | 2 | Dial starts |

Additional attributes on `<Dial>`:
- `recordingStatusCallback` — webhook URL
- `recordingStatusCallbackEvent` — `in-progress`, `completed`, `absent`
- `trim` — `trim-silence` or `do-not-trim`

```javascript
// Codebase pattern: call-tracking-inbound.js
const dial = twiml.dial({
  record: 'record-from-answer-dual',
  recordingStatusCallback: `https://${domainName}/callbacks/call-status`,
  recordingStatusCallbackEvent: 'completed',
});
dial.number(businessNumber);
```

## 3. `<Start><Recording>` (Background Recording)

Starts a background recording that persists across TwiML documents. Continues until call ends or stopped via API.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `recordingStatusCallback` | URL | — | **Must be absolute URL** (relative paths cause error 11200) |
| `recordingStatusCallbackEvent` | string | `completed` | Events to subscribe |
| `recordingStatusCallbackMethod` | string | `POST` | HTTP method |
| `recordingTrack` | string | `both` | `inbound`, `outbound`, or `both` — **has no observable effect on output** |
| `trim` | string | `trim-silence` | `trim-silence` or `do-not-trim` |

**Always produces 2-channel recordings** regardless of `recordingTrack`. Source: `StartCallRecordingTwiML`.

```javascript
// Codebase pattern: agent-a-inbound.protected.js
const start = twiml.start();
start.recording({
  recordingStatusCallback: `https://${context.DOMAIN_NAME}/conversation-relay/recording-complete`,
  recordingStatusCallbackEvent: 'completed',
});
// Recording continues through subsequent TwiML
const connect = twiml.connect();
connect.conversationRelay({ url: relayUrl });
```

## 4. Calls API `Record=true`

Records at outbound call creation time. Defaults to mono.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `record` | boolean | false | Enable recording |
| `recordingChannels` | string | `mono` | `mono` or `dual` |
| `recordingTrack` | string | `both` | `inbound`, `outbound`, `both` |
| `recordingStatusCallback` | URL | — | Webhook URL |
| `recordingStatusCallbackEvent` | string[] | `completed` | Events |
| `trim` | string | `do-not-trim` | Trim behavior |

Source: `OutboundAPI`. **Defaults to mono (1 channel).**

```javascript
const call = await client.calls.create({
  to: '+1234567890',
  from: '+1987654321',
  url: 'https://example.com/twiml',
  record: true,
  recordingChannels: 'dual', // Must specify for dual
  recordingStatusCallback: 'https://example.com/rec-callback',
});
```

## 5. Start Call Recording API (`POST /Calls/{sid}/Recordings`)

Full programmatic control: start, pause, resume, stop mid-call.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `recordingChannels` | string | `mono` | `mono` or `dual` |
| `recordingTrack` | string | `both` | `inbound`, `outbound`, `both` — **actually isolates audio** |
| `recordingStatusCallback` | URL | — | Webhook URL |
| `recordingStatusCallbackEvent` | string[] | — | Events |
| `trim` | string | `do-not-trim` | Trim behavior |

Source: `StartCallRecordingAPI`. MCP tool: `start_call_recording`.

**Pause/Resume**: `update_call_recording` with `status: 'paused'` or `status: 'in-progress'`. Use `pauseBehavior: 'skip'` (removes paused time) or `'silence'` (inserts dead air). Use `Twilio.CURRENT` as recording SID to reference the active recording.

**Cannot be used on ConversationRelay calls** — returns "not eligible for recording."

```javascript
// Start
const rec = await client.calls(callSid).recordings.create({
  recordingChannels: 'dual',
  recordingTrack: 'inbound', // Actually isolates to child leg audio only
});

// Pause (skip)
await client.calls(callSid).recordings('Twilio.CURRENT').update({
  status: 'paused',
  pauseBehavior: 'skip',
});

// Resume
await client.calls(callSid).recordings('Twilio.CURRENT').update({
  status: 'in-progress',
});
```

## 6. Conference `record` Attribute

Records the entire conference mix. Always mono (all participants mixed).

**TwiML**:
```javascript
twiml.dial().conference({
  record: 'record-from-start',
  recordingStatusCallback: callbackUrl,
  recordingStatusCallbackEvent: 'completed',
}, conferenceName);
```

**Participants API**: `conferenceRecord: true` (boolean, NOT the TwiML string values).

Source: `Conference`.

## 7. Elastic SIP Trunk Recording

Trunk-level configuration via API. Applies to all calls on the trunk.

| Mode | Channels | Starts When |
|------|----------|-------------|
| `do-not-record` | — | Default (no recording) |
| `record-from-answer` | 1 (mono) | Call answers |
| `record-from-ringing` | 1 (mono) | Call starts ringing |
| `record-from-answer-dual` | 2 | Call answers |
| `record-from-ringing-dual` | 2 | Call starts ringing |

Trim: `trim-silence` or `do-not-trim`.

Source: `Trunking`. MCP tools: `get_trunk_recording`, `update_trunk_recording`.

**Trunk recording is on the trunk leg's call SID**, not the parent API call. Channel assignment: ch1=Twilio/originator, ch2=SIP/PBX (opposite from API recordings).

```javascript
// Configure via API
await client.trunking.v1.trunks(trunkSid).recordings().update({
  mode: 'record-from-answer-dual',
  trim: 'do-not-trim',
});
```
