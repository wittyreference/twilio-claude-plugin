---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Dual-channel recording mechanics, channel assignment rules, and audio formats. -->
<!-- ABOUTME: Live-validated channel mapping for API, TwiML, and SIP trunk recordings. -->

# Channel Mapping & Audio Formats

## Channel Assignment (Live-Validated)

Channel assignment is NOT universal — it depends on how the recording was created.

### API/TwiML Recordings

Covers: `DialVerb`, `StartCallRecordingTwiML`, `StartCallRecordingAPI`, `OutboundAPI`

| Channel | Contains | Twilio Term |
|---------|----------|-------------|
| **Channel 1** | Child leg / TO number / inbound audio | The party being called |
| **Channel 2** | Parent leg / API-initiated side / outbound audio | The caller / initiator |

Validated across 6 recording methods with Voice Intelligence `channel-map` operator. Consistent result every time.

### SIP Trunk Recordings

Source: `Trunking`

| Channel | Contains | Description |
|---------|----------|-------------|
| **Channel 1** | Twilio / originating side | TwiML audio, TTS, the API caller |
| **Channel 2** | SIP / terminating side | PBX audio (e.g., Asterisk playback) |

**Opposite from API recordings.** This matters for Voice Intelligence participant mapping.

### Voice Intelligence Participant Mapping

Set `channel_participant` to match the actual channel assignment:

```javascript
// For API/TwiML recordings
const channel = {
  media_properties: { source_sid: recordingSid },
  participants: [
    { channel_participant: 1, user_id: 'customer' },  // TO number
    { channel_participant: 2, user_id: 'agent' },      // API/parent side
  ],
};

// For SIP trunk recordings (reversed)
const channel = {
  media_properties: { source_sid: recordingSid },
  participants: [
    { channel_participant: 1, user_id: 'agent' },      // Twilio side
    { channel_participant: 2, user_id: 'customer' },    // PBX side
  ],
};
```

## Track Isolation

### API `recordingTrack` (Works)

The `start_call_recording` API's `recordingTrack` parameter actually isolates audio:

| `recordingTrack` | What's Recorded | Validated |
|-----------------|-----------------|-----------|
| `inbound` | Audio FROM the remote party (TO number's voice) | CH1 SILENT, content on CH2 |
| `outbound` | Audio TO the remote party (parent leg TTS/audio) | CH1 SILENT, content on CH2 |
| `both` | Both parties (default) | Both channels have audio |

"Inbound" and "outbound" are Twilio-centric:
- **Inbound** = arriving at Twilio from the network
- **Outbound** = leaving Twilio toward the network

### TwiML `recordingTrack` (Does NOT Work)

`<Start><Recording recordingTrack="inbound|outbound">` has **no observable effect**. Both channels always contain audio. The recording is always 2 channels. Use the API for track isolation.

## Audio Formats

| Property | Value |
|----------|-------|
| Native format | WAV (RIFF), PCM 16-bit |
| Sample rate | 8000 Hz |
| Mono file size | ~1 MB/min |
| Dual file size | ~2 MB/min |
| MP3 available | Yes (append `.mp3` to URL) |
| MP3 file size | ~120 KB/min |

## Mono vs Dual: When to Use Which

| Use Case | Recommendation | Why |
|----------|---------------|-----|
| Compliance archival | Mono | Smaller files, simpler |
| Voice Intelligence transcription | **Dual** | Speaker attribution requires separate channels |
| Quality analysis | Dual | Isolate each party for clarity metrics |
| Simple playback | Mono | One audio stream, no channel selection needed |
| Conference recording | Mono (only option) | All participants mixed |
| Training/review | Dual | Listen to each party separately |

## Conference Recording

Conference recordings are always **mono** (1 channel). All participants are mixed together. There is no dual-channel option for conference recording.

To get per-participant audio in a conference, record each participant's call leg separately using `start_call_recording` on individual call SIDs (not the conference SID).
