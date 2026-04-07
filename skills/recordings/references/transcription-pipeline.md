---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: End-to-end recording-to-transcription workflow with Voice Intelligence. -->
<!-- ABOUTME: Covers transcript creation, channel mapping, Language Operators, and codebase patterns. -->

# Recording → Transcription Pipeline

## Prerequisites

1. **Voice Intelligence Service** — Created in Console only (no API). Console → Voice → Voice Intelligence → Create Service. Copy the `GA...` SID.
2. **Language Operators** (optional) — Configure on the service for auto-analysis (summarization, sentiment, custom validators). Operators run automatically on every transcript created on that service.
3. **Env var**: `TWILIO_INTELLIGENCE_SERVICE_SID=GA...`

## Step 1: Recording Callback

When a recording completes, the `recordingStatusCallback` fires:

```javascript
// recording-complete.protected.js
exports.handler = async function (context, event, callback) {
  const { RecordingSid, RecordingUrl, RecordingStatus, CallSid } = event;

  if (RecordingStatus !== 'completed') {
    // Only process completed recordings
    return callback(null, response);
  }

  const recordingMediaUrl = `${RecordingUrl}.mp3`;
  // ... proceed to create transcript
};
```

## Step 2: Create Transcript

Use `source_sid` (Recording SID), NOT `media_url`. The Intelligence API cannot authenticate to `api.twilio.com`.

```javascript
const channel = {
  media_properties: {
    source_sid: RecordingSid, // RE... — NOT a URL
  },
  participants: [
    { channel_participant: 1, user_id: 'caller' },
    { channel_participant: 2, user_id: 'agent' },
  ],
};

const transcript = await client.intelligence.v2.transcripts.create({
  serviceSid: intelligenceServiceSid,
  channel,
  customerKey: CallSid, // Correlation key for later lookup
});
```

### Channel Participant Mapping

The `participants` array defines speaker labels for the transcript:

| `channel_participant` | Maps to | Typical Label |
|----------------------|---------|---------------|
| 1 | Channel 1 audio | `caller` / TO number / child leg |
| 2 | Channel 2 audio | `agent` / API-initiated side / parent leg |

**For SIP trunk recordings**, channel assignment is reversed (ch1=Twilio, ch2=PBX). Adjust participant mapping accordingly.

For mono recordings, both speakers are on channel 1. Voice Intelligence still attempts speaker diarization.

## Step 3: Transcript Completion

Voice Intelligence sends a webhook when the transcript is ready:

**Event**: `voice_intelligence_transcript_available`

Configure in Console: Voice → Voice Intelligence → [Service] → Webhooks.

```javascript
// transcript-complete.protected.js
const { transcript_sid, customer_key, event_type } = event;

if (event_type !== 'voice_intelligence_transcript_available') {
  return; // Skip other event types
}
```

## Step 4: Fetch Results

### Sentences

```javascript
const sentences = await client.intelligence.v2
  .transcripts(transcript_sid)
  .sentences.list({ limit: 200 });

for (const s of sentences) {
  const speaker = s.mediaChannel === 1 ? 'Caller' : 'Agent';
  console.log(`${speaker}: ${s.transcript}`);
  // s.confidence, s.startTime, s.endTime also available
}
```

### Operator Results

```javascript
const ops = await client.intelligence.v2
  .transcripts(transcript_sid)
  .operatorResults.list({ limit: 20 });

for (const op of ops) {
  // Text generation operators:
  console.log(op.name, op.textGenerationResults?.result);
  // Classification operators:
  console.log(op.name, op.labelResults);
  // Extraction operators:
  console.log(op.name, op.extractedResults);
}
```

## Dual Service Pattern

Use separate Intelligence Services to control which operators run:

| Service | Operators | Use Case |
|---------|-----------|----------|
| `twilio-agent-factory` | Summary + Sentiment (auto) | Demo calls, production |
| `recording-validation` | 5 custom validators | Recording matrix testing |
| `no-auto-transcribe` | None | Manual transcript creation, no operators |

Operators are per-service and auto-run on ALL transcripts. No per-transcript bypass. Create separate services for different operator sets.

## MCP Validation Flow

```
validate_recording(recordingSid) → polls until completed, checks duration
    ↓
validate_transcript(transcriptSid) → polls until completed, checks sentences
    ↓
validate_voice_ai_flow(callSid) → end-to-end: call + recording + transcript + Sync
```

## PCI Mode Warning

**PCI mode permanently taints recordings for Voice Intelligence.** Recordings created while PCI mode is enabled on the account cannot be transcribed, even after PCI is disabled. The taint is per-recording, not per-account — recordings created after PCI disable work fine.
