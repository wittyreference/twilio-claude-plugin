---
name: Deep Validation
description: Validation patterns beyond HTTP 200. Use when building validation logic, testing Twilio integrations, or understanding status progression, Voice Insights, and debugger alert patterns.
---

# Deep Validation Patterns for Twilio

This skill covers validation patterns that go beyond simple API response checking. Load this skill when testing Twilio integrations or building validation into workflows.

## Why Deep Validation Matters

A 200 OK from Twilio API doesn't guarantee success. The operation may be queued but:
- TwiML validation could fail later
- Carrier could reject the message
- Webhook could return errors
- Call could fail to connect
- Voice quality could be degraded

Tests that only check for 200 OK give false confidence.

## The Deep Validation Pattern

For each operation type, check multiple signals after API operations:

### SMS/MMS Validation

```typescript
interface MessageValidation {
  // Primary: Check message status progression
  resourceStatus: {
    passed: boolean;
    status: 'queued' | 'sending' | 'sent' | 'delivered' | 'undelivered' | 'failed';
  };

  // Secondary: Check for debugger alerts
  debuggerAlerts: {
    passed: boolean;
    alerts: Alert[];  // Error codes 30003, 30004, etc.
  };

  // Optional: Check callback data (if callbacks configured)
  callbackReceived: {
    passed: boolean;
    data: object;
  };
}
```

**Status progression**: `queued` → `sending` → `sent` → `delivered`

**Common failure codes**:
| Code | Meaning |
|------|---------|
| 30003 | Unreachable destination |
| 30004 | Message blocked |
| 30005 | Unknown destination |
| 30006 | Landline or unreachable |
| 30007 | Carrier violation |

### Voice Call Validation

```typescript
interface CallValidation {
  // Primary: Check call status
  resourceStatus: {
    passed: boolean;
    status: 'queued' | 'ringing' | 'in-progress' | 'completed' | 'busy' | 'no-answer' | 'failed';
  };

  // Secondary: Check call events for HTTP errors
  callEvents: {
    passed: boolean;
    events: Event[];  // HTTP requests/responses during call
  };

  // Secondary: Check debugger for TwiML errors
  debuggerAlerts: {
    passed: boolean;
    alerts: Alert[];
  };

  // Quality: Voice Insights call summary
  voiceInsights: {
    passed: boolean;
    summary: {
      callQuality: string;
      disposition: string;
      jitter: number;
      packetLoss: number;
    };
  };
}
// The enhanced Voice Insights check now interprets specific quality tags
// (high_jitter, high_packet_loss, silence, etc.), SIP response codes
// (range-based + 20 specific codes), and edge-specific quality metrics
// against thresholds. See the Voice Insights skill for full diagnostic workflows.
```

**Status progression**: `queued` → `ringing` → `in-progress` → `completed`

### Conference Validation

```typescript
interface ConferenceValidation {
  // All call validation checks, plus:

  // Conference-specific: Summary metrics
  conferenceSummary: {
    passed: boolean;
    participantCount: number;
    duration: number;
    aggregateQuality: string;
  };

  // Per-participant quality
  participantSummaries: {
    passed: boolean;
    participants: ParticipantSummary[];
  };
}
```

### Verification Validation

```typescript
interface VerificationValidation {
  // Primary: Check verification status
  resourceStatus: {
    passed: boolean;
    status: 'pending' | 'approved' | 'canceled' | 'max_attempts_reached' | 'expired';
  };

  // Secondary: Debugger alerts
  debuggerAlerts: {
    passed: boolean;
    alerts: Alert[];
  };
}
```

### Video Room Validation

A 200 OK from Video Room API doesn't guarantee success. Participants may fail to connect, tracks may not publish, or recordings may fail silently.

```typescript
interface VideoRoomValidation {
  // Primary: Room status and type
  roomStatus: {
    passed: boolean;
    status: 'in-progress' | 'completed' | 'failed';
    type: string;  // Should be 'group' (not legacy peer-to-peer/go)
  };

  // Participant checks
  participants: {
    passed: boolean;
    count: number;
    connected: number;
    withTracks: number;  // Participants publishing audio/video
  };

  // Optional: Transcription (Healthcare use case)
  transcription?: {
    passed: boolean;
    status: 'started' | 'stopped' | 'failed';
    sentenceCount: number;
    speakers: string[];
  };

  // Optional: Recording (Professional/Proctoring use case)
  recordings?: {
    passed: boolean;
    count: number;
    byParticipant: Record<string, { audio: number; video: number }>;
    allCompleted: boolean;
  };

  // Optional: Composition (Professional use case)
  composition?: {
    passed: boolean;
    status: 'enqueued' | 'processing' | 'completed' | 'failed';
    mediaAccessible: boolean;
  };
}
```

**Video Validation Checklist:**

```
ALWAYS CHECK (every room):
□ Room Resource - status, type = 'group', duration
□ Participant count - matches expected
□ Published tracks - participants publishing audio/video
□ Subscribed tracks - participants receiving each other

WHEN USING TRANSCRIPTION (add these):
□ Transcription resource exists and status = 'started' or 'stopped'
□ Sentences appearing (query sentences endpoint)
□ Speaker attribution working (ParticipantSid in results)

WHEN USING RECORDING (add these):
□ Recording resources exist for each participant
□ Track recordings for audio + video (+ screen if applicable)
□ After room ends: all recordings status = 'completed'

WHEN USING COMPOSITION (add these):
□ Composition created AFTER room ends (not during)
□ Composition status progresses to 'completed'
□ Media URL accessible (HTTP 200)
```

**Common Video Failure Patterns:**

| Symptom | Cause | Solution |
|---------|-------|----------|
| Room status = 'completed', duration = 0 | Empty room timeout | Set longer `emptyRoomTimeout` |
| Participant connected but no tracks | SDK didn't publish | Check client-side `publishTrack()` |
| Transcription exists but no sentences | Speech not detected | Check audio track is publishing |
| Composition status = 'failed' | Room still in-progress | Wait for room to complete first |
| Media URL returns 404 | External storage misconfigured | Check S3 credentials and bucket |
| Room type is 'peer-to-peer' or 'go' | Legacy room created | Always use type = 'group' |

## Timing Considerations

### Voice/Conference Insights Timing

Summaries are NOT immediately available after call/conference ends:

| State | When Available | Use |
|-------|----------------|-----|
| Partial | ~2 minutes after end (no SLA) | Quick validation |
| Complete | 30 minutes after end (guaranteed) | Final validation |

Check `processingState` field:
```typescript
const summary = await client.insights.v1.calls(callSid).summary().fetch();
if (summary.processingState === 'complete') {
  // Data is final and immutable
} else if (summary.processingState === 'partial') {
  // Data may change, consider polling or waiting
}
```

### Video Room Timing

| Resource | When Available |
|----------|----------------|
| Room participants | Immediately |
| Published tracks | After participant publishes |
| Transcription sentences | ~2-5 seconds after speech |
| Recordings | After room ends + processing |
| Composition | After room ends + encoding time |

**Composition encoding time** depends on duration:
- Short rooms (< 5 min): ~30 seconds
- Medium rooms (5-30 min): 2-5 minutes
- Long rooms (> 30 min): 10+ minutes

**CRITICAL:** Compositions can only be created AFTER the room ends (status = 'completed').

### Debugger Alert Timing

Query debugger for alerts in the timeframe of your operation:
```typescript
const alerts = await client.monitor.alerts.list({
  startDate: operationStartTime,
  endDate: new Date(),
  logLevel: 'error'
});
```

## MCP Validation Tools (Preferred Method)

**USE THESE MCP TOOLS** instead of CLI commands or manual API polling. They're available via the Twilio MCP server.

### Available Tools

| MCP Tool | Purpose |
|----------|---------|
| `validate_call` | Deep call validation with Voice Insights, events, content quality |
| `validate_message` | Message delivery validation with debugger check |
| `validate_recording` | Recording completion validation |
| `validate_transcript` | Transcript completion + sentence validation |
| `validate_debugger` | Account-wide debugger error check |
| `validate_voice_ai_flow` | Full Voice AI flow (call + recording + transcript + SMS) |
| `validate_two_way` | Two-way conversation validation |
| `validate_language_operator` | Language Operator results validation |
| `validate_video_room` | Video room validation with participants, tracks, transcription, recording, composition |
| `validate_sync_document` | Sync Document data structure validation |
| `validate_sync_list` | Sync List item count and structure validation |
| `validate_sync_map` | Sync Map keys and values validation |
| `validate_task` | TaskRouter task deep validation |
| `validate_sip` | SIP infrastructure validation |

### Using MCP Tools (Claude Code)

```text
# Validate a call - checks status, events, Voice Insights
validate_call(callSid: "CA123...", validateContent: true)

# Validate message delivery
validate_message(messageSid: "SM456...")

# Full Voice AI flow validation
validate_voice_ai_flow(
  callSid: "CA123...",
  forbiddenPatterns: ["application error", "please try again"]
)

# Check debugger for recent errors
validate_debugger(lookbackSeconds: 300, logLevel: "error")

# Basic video room validation
validate_video_room(roomSid: "RM123...")

# Healthcare use case (with transcription)
validate_video_room(
  roomSid: "RM123...",
  expectedParticipants: 3,
  checkTranscription: true
)

# Professional use case (with recording + composition)
validate_video_room(
  roomSid: "RM123...",
  checkRecording: true,
  checkComposition: true,
  waitForCompositionComplete: true,
  timeout: 300000  # 5 min for composition
)

# Proctoring use case (recording only, no composition)
validate_video_room(
  roomSid: "RM123...",
  expectedParticipants: 1,
  checkPublishedTracks: true,  # Verify screen share
  checkRecording: true
)
```

### Why MCP Tools Over CLI

| CLI Approach | MCP Tool Approach |
|--------------|-------------------|
| Manual polling with retries | Automatic polling with timeout |
| Parse text output | Structured JSON response |
| Multiple commands needed | Single tool call |
| No content validation | Forbidden pattern detection |
| Manual error correlation | Unified error reporting |

## Implementing Deep Validation

### Programmatic Pattern

```typescript
// Deep validation for a message
async function validateMessage(client, messageSid, options = {}) {
  const result = { success: true, errors: [] };

  // 1. Poll for terminal status
  let message;
  const startTime = Date.now();
  const timeout = options.timeout || 30000;

  while (Date.now() - startTime < timeout) {
    message = await client.messages(messageSid).fetch();
    if (['delivered', 'undelivered', 'failed'].includes(message.status)) break;
    await new Promise(r => setTimeout(r, 2000));
  }

  if (!['delivered', 'sent'].includes(message.status)) {
    result.success = false;
    result.errors.push(`Message status: ${message.status} (error: ${message.errorCode})`);
  }

  // 2. Check debugger
  const alerts = await client.monitor.alerts.list({
    startDate: new Date(Date.now() - 300000),
    logLevel: 'error'
  });

  const relatedAlerts = alerts.filter(a =>
    a.resourceSid === messageSid
  );

  if (relatedAlerts.length > 0) {
    result.success = false;
    result.errors.push(...relatedAlerts.map(a => `Alert ${a.errorCode}: ${a.alertText}`));
  }

  return result;
}
```

### For Voice Calls

```typescript
async function validateCall(client, callSid, options = {}) {
  const result = { success: true, errors: [] };

  // 1. Check call status
  const call = await client.calls(callSid).fetch();
  if (call.status !== 'completed') {
    result.success = false;
    result.errors.push(`Call status: ${call.status}`);
  }

  // 2. Check call events for HTTP errors
  const events = await client.calls(callSid).events().list();
  const httpErrors = events.filter(e =>
    e.response && e.response.statusCode >= 400
  );

  if (httpErrors.length > 0) {
    result.success = false;
    result.errors.push(...httpErrors.map(e =>
      `HTTP ${e.response.statusCode} at ${e.request.url}`
    ));
  }

  // 3. Check debugger
  const alerts = await client.monitor.alerts.list({
    startDate: new Date(Date.now() - 300000),
    logLevel: 'error'
  });

  const relatedAlerts = alerts.filter(a =>
    a.resourceSid === callSid
  );

  if (relatedAlerts.length > 0) {
    result.success = false;
    result.errors.push(...relatedAlerts.map(a => `Alert ${a.errorCode}: ${a.alertText}`));
  }

  // 4. Optional: Voice Insights (wait for partial data)
  if (options.checkVoiceInsights) {
    await new Promise(r => setTimeout(r, 120000)); // Wait ~2 min for partial
    const summary = await client.insights.v1.calls(callSid).summary().fetch();
    if (summary.callQuality === 'poor') {
      result.errors.push(`Poor call quality: jitter=${summary.jitter}, packetLoss=${summary.packetLoss}`);
    }
  }

  return result;
}
```

## Integration with Jest Tests

```typescript
// Custom matchers for deep validation
expect.extend({
  async toBeDelivered(messageSid) {
    const message = await client.messages(messageSid).fetch();
    const pass = ['delivered', 'sent'].includes(message.status);
    return {
      pass,
      message: () => `Expected message ${messageSid} to be delivered, got ${message.status}`
    };
  },

  async toCompleteSuccessfully(callSid) {
    const call = await client.calls(callSid).fetch();
    const pass = call.status === 'completed';
    return {
      pass,
      message: () => `Expected call ${callSid} to complete, got ${call.status}`
    };
  }
});

// Usage in tests
test('SMS delivers successfully', async () => {
  const message = await sendTestSms();
  await expect(message.sid).toBeDelivered();
});
```

## Validation Checklist

### For Every Operation

- [ ] Check resource status via API
- [ ] Query debugger for errors in timeframe
- [ ] Verify no unexpected alerts

### For Voice Calls

- [ ] Check call events for HTTP errors
- [ ] Verify Voice Insights summary (after 2+ minutes)
- [ ] Check quality metrics if available

### For Conferences

- [ ] All call validation checks
- [ ] Conference summary metrics
- [ ] Per-participant quality checks

### For SMS/MMS

- [ ] Wait for terminal status (delivered/failed)
- [ ] Check for carrier rejection codes
- [ ] Verify callback data if configured

### For Video Rooms

- [ ] Verify room type is 'group' (not legacy peer-to-peer/go)
- [ ] Check participant count matches expected
- [ ] Verify participants are publishing tracks
- [ ] If using transcription: check status and sentences
- [ ] If using recording: verify recordings exist per participant
- [ ] If using composition: wait for room end, then check composition status
- [ ] Verify composition media is accessible

## Anti-Patterns

### Don't Do This

```typescript
// BAD: Only checking HTTP status
const response = await client.messages.create({ to, from, body });
if (response.sid) {
  console.log('Success!');  // False confidence
}
```

### Do This Instead (MCP Tool)

```text
# BEST: Use MCP validation tool
validate_message(messageSid: "SM123...", waitForTerminal: true)
```

### Do This Instead (Programmatic)

```typescript
// GOOD: Deep validation
const message = await client.messages.create({ to, from, body });
const validation = await validateMessage(client, message.sid, {
  timeout: 30000
});

if (validation.success) {
  console.log('Message delivered successfully');
} else {
  console.log('Issues found:', validation.errors);
}
```
