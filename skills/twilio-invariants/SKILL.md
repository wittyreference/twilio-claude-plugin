# Twilio Architectural Invariants

Rules that have each caused real debugging time loss. These are proven gotchas that affect any Twilio developer. Load this skill at the start of any Twilio development session.

---

## The 9 Invariants

### 1. `Twilio.Response.setBody()` Requires Strings

**Wrong:**
```javascript
response.setBody({ success: true });
```

**What happens:** `Buffer.from(object)` TypeError at runtime.

**Right:**
```javascript
response.appendHeader('Content-Type', 'application/json');
response.setBody(JSON.stringify({ success: true }));
```

Always `JSON.stringify()` + set the Content-Type header when returning JSON from Twilio Functions.

---

### 2. `console.error()` Triggers 82005 Debugger Alerts

Any `console.error()` call in a Twilio Function creates an 82005 alert in the Twilio Debugger. This pollutes the debugger with noise and can mask real errors.

**Rule:** Use `console.log()` for operational logging. Reserve `console.error()` for actual catch blocks only. Note: `console.warn()` triggers 82004 alerts.

---

### 3. ConversationRelay Uses `last`, NOT `isFinal`

The ConversationRelay WebSocket protocol sends `{ last: true }` to indicate the final message. Checking `message.isFinal` (a common assumption) silently drops all follow-up utterances with no error.

**Wrong:**
```javascript
if (message.isFinal) { /* never triggers */ }
```

**Right:**
```javascript
if (message.last) { /* correct field name */ }
```

---

### 4. Environment Variables Can Reset on Deploy

`twilio serverless:deploy` does NOT preserve runtime environment variables that were set via the Console or API. After deployment, always verify your environment variables are still set correctly.

Check after deploy:
```bash
twilio api:serverless:v1:services:environments:variables:list \
  --service-sid $SERVICE_SID --environment-sid $ENV_SID
```

---

### 5. CLI Profile and `.env` Are Independent

The active Twilio CLI profile can point to your main account while `.env` has a subaccount SID (or vice versa). This means:
- `twilio serverless:deploy` uses the **CLI profile**
- Your Functions at runtime use the **environment variables**

Always verify both before operations:
```bash
twilio profiles:list          # Check active profile
cat .env | grep ACCOUNT_SID   # Check env file
```

---

### 6. TwiML: One Document Controls a Call at a Time

When you update a participant's TwiML (via REST API), they **exit their current state** — conference, queue, or any other TwiML context.

**Exception:** Background processes started with `<Start>` are NOT affected:
- `<Start><Stream>` — forks a background audio stream
- `<Start><Recording>` — forks a background recording
- `<Start><Siprec>` — forks a background SIPREC stream

These continue running even when the main TwiML document changes.

**Dangerous pattern:**
```javascript
// This pulls the participant OUT of the conference
await client.calls(callSid).update({
  twiml: '<Response><Say>Hello</Say></Response>'
});
```

---

### 7. Voice Intelligence: `source_sid`, NOT `media_url`

When creating transcripts with Voice Intelligence (Conversational Intelligence), use the Recording SID as `source_sid`, not `media_url`.

**Why:** The `media_url` for recordings requires authentication that the Intelligence API cannot provide. Using `media_url` will silently fail or produce empty transcripts.

**Right:**
```javascript
const transcript = await client.intelligence.v2.transcripts.create({
  serviceSid: intelligenceServiceSid,
  channel: { participants: [...] },
  source_sid: recordingSid  // Use Recording SID, not media_url
});
```

---

### 8. Google Neural Voices for ConversationRelay

Polly voices (e.g., `Polly.Amy`) may be blocked by ConversationRelay with error 64101. Use Google Neural voices as the default.

**Default recommendation:** `Google.en-US-Neural2-F`

**Voice name format note:** ConversationRelay voice names use the format `Google.en-US-Neural2-F` (with `Google.` prefix). This differs from some newer voice formats.

```javascript
// ConversationRelay TwiML
twiml.connect().conversationRelay({
  url: 'wss://your-server.com/ws',
  voice: 'Google.en-US-Neural2-F',  // Safe default
  // NOT: voice: 'Polly.Amy'        // May trigger error 64101
});
```

---

### 9. `<Start><Recording>` Syntax Is `.recording()`, NOT `.record()`

When using the Twilio Node.js helper library to create background recordings:

**Wrong:**
```javascript
twiml.start().record({ recordingStatusCallback: '/callback' });
```

**Right:**
```javascript
twiml.start().recording({ recordingStatusCallback: '/callback' });
```

The method name is `.recording()` (noun form), not `.record()` (verb form). This applies specifically to `<Start><Recording>` — the standalone `<Record>` verb does use `.record()`.

---

## When to Reference This Document

- **Session start**: Skim the full list as a refresh
- **Debugging silent failures**: Check if your issue matches an invariant
- **Code review**: Verify none of these patterns appear in new code
- **ConversationRelay work**: Invariants 3, 8 are critical
- **Deployment**: Invariants 4, 5 are critical
- **Voice Intelligence**: Invariant 7 is critical
- **TwiML generation**: Invariants 1, 6, 9 are critical
