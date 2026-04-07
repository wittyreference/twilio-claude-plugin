---
name: "media-streams"
description: "Twilio development skill: media-streams"
---

# Media Streams WebSocket Protocol Reference

## Incoming Messages (Twilio → Your Server)

### `connected` — WebSocket established
```json
{
  "event": "connected",
  "protocol": "Call",
  "version": "1.0.0"
}
```

### `start` — Stream metadata (sent once)
```json
{
  "event": "start",
  "sequenceNumber": "1",
  "start": {
    "accountSid": "ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
    "streamSid": "MZxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
    "callSid": "CAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
    "tracks": ["inbound"],
    "mediaFormat": {
      "encoding": "audio/x-mulaw",
      "sampleRate": 8000,
      "channels": 1
    },
    "customParameters": {
      "callerNumber": "+15551234567"
    }
  },
  "streamSid": "MZxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}
```

### `media` — Audio data
```json
{
  "event": "media",
  "sequenceNumber": "3",
  "media": {
    "track": "inbound",
    "chunk": "1",
    "timestamp": "5",
    "payload": "<base64-encoded-mulaw-audio>"
  },
  "streamSid": "MZxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}
```

- `track`: `"inbound"` (caller audio) or `"outbound"` (TTS/played audio)
- `timestamp`: Milliseconds from stream start
- `payload`: Base64-encoded mulaw audio, 8kHz, mono, no file headers

### `dtmf` — Keypress detected (bidirectional only)
```json
{
  "event": "dtmf",
  "sequenceNumber": "5",
  "dtmf": {
    "track": "inbound_track",
    "digit": "1"
  },
  "streamSid": "MZxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}
```

### `mark` — Playback milestone reached (bidirectional only)
```json
{
  "event": "mark",
  "sequenceNumber": "4",
  "mark": {
    "name": "my-label"
  },
  "streamSid": "MZxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}
```

Sent when audio preceding a sent mark has finished playing.

### `stop` — Stream ended
```json
{
  "event": "stop",
  "sequenceNumber": "5",
  "stop": {
    "accountSid": "ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
    "callSid": "CAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  },
  "streamSid": "MZxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}
```

## Outgoing Messages (Your Server → Twilio)

### Send audio
```json
{
  "event": "media",
  "streamSid": "MZxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "media": {
    "payload": "<base64-encoded-mulaw-audio>"
  }
}
```

Audio must be mulaw-encoded at 8000 Hz, mono, base64-encoded, with no WAV/file headers.

### Send mark (track playback position)
```json
{
  "event": "mark",
  "streamSid": "MZxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "mark": {
    "name": "utterance-end"
  }
}
```

### Clear audio buffer (interrupt)
```json
{
  "event": "clear",
  "streamSid": "MZxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}
```

Empties the queued audio buffer. Use this for barge-in/interruption.
