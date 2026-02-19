# Deep Validation Patterns for Twilio

Validation patterns that go beyond simple API response checking. Load this skill when testing Twilio integrations or building validation into workflows.

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

**Status progression**: `queued` -> `sending` -> `sent` -> `delivered`

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
```

**Status progression**: `queued` -> `ringing` -> `in-progress` -> `completed`

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

### Debugger Alert Timing

Query debugger for alerts in the timeframe of your operation:
```typescript
const alerts = await client.monitor.alerts.list({
  startDate: operationStartTime,
  endDate: new Date(),
  logLevel: 'error'
});
```

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

## Anti-Patterns

### Don't Do This

```typescript
// BAD: Only checking HTTP status
const response = await client.messages.create({ to, from, body });
if (response.sid) {
  console.log('Success!');  // False confidence
}
```

### Do This Instead

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
