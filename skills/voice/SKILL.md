---
name: voice
description: Build Twilio Voice apps with TwiML verbs, IVRs, call routing, recordings, and conferencing. Use when working with phone calls, voice webhooks, or call handling.
---

# Voice Skill

Comprehensive knowledge for building Twilio Voice applications - from simple IVRs to complex call center solutions.

## TwiML Voice Verbs Reference

### Primary Verbs

| Verb | Purpose | Key Attributes |
|------|---------|----------------|
| `<Say>` | Text-to-speech | voice, language, loop |
| `<Play>` | Play audio file | loop, digits |
| `<Gather>` | Collect DTMF/speech | input, timeout, numDigits, action |
| `<Dial>` | Connect parties | callerId, timeout, record, action |
| `<Record>` | Record audio | maxLength, transcribe, action |
| `<Conference>` | Multi-party call | muted, beep, startConferenceOnEnter |
| `<Enqueue>` | Add to call queue | waitUrl, action |
| `<Hangup>` | End call | - |
| `<Redirect>` | Go to new TwiML | method |
| `<Pause>` | Add silence | length |
| `<Reject>` | Reject call | reason |
| `<Connect>` | Media streams | - |

### Dial Nouns (What to dial)

| Noun | Purpose | Example |
|------|---------|---------|
| `<Number>` | Phone number | `dial.number('+1234567890')` |
| `<Client>` | Twilio Client | `dial.client('agent-1')` |
| `<Sip>` | SIP endpoint | `dial.sip('sip:user@domain.com')` |
| `<Conference>` | Conference room | `dial.conference('room-123')` |
| `<Queue>` | Call queue | `dial.queue('support-queue')` |

---

## Voice Webhook Parameters

### Inbound Call Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `CallSid` | Unique call identifier | `CAxxxxxxxx` |
| `AccountSid` | Your Account SID | `ACxxxxxxxx` |
| `From` | Caller's number (E.164) | `+14155551234` |
| `To` | Called number (E.164) | `+14155559876` |
| `CallStatus` | Current status | `ringing`, `in-progress` |
| `Direction` | Call direction | `inbound`, `outbound-api` |
| `CallerName` | CNAM lookup result | `John Smith` |
| `FromCity` | Caller's city | `San Francisco` |
| `FromState` | Caller's state | `CA` |
| `FromCountry` | Caller's country | `US` |
| `FromZip` | Caller's ZIP | `94102` |
| `ApiVersion` | API version | `2010-04-01` |

### Gather Results

| Parameter | Description |
|-----------|-------------|
| `Digits` | DTMF digits pressed |
| `SpeechResult` | Transcribed speech text |
| `Confidence` | Recognition confidence (0.0-1.0) |
| `Language` | Detected language |

### Dial Status Callback

| Parameter | Description |
|-----------|-------------|
| `DialCallStatus` | `completed`, `busy`, `no-answer`, `failed`, `canceled` |
| `DialCallSid` | SID of the dialed leg |
| `DialCallDuration` | Duration in seconds |
| `RecordingUrl` | URL if call was recorded |

### Recording Callback

| Parameter | Description |
|-----------|-------------|
| `RecordingSid` | Unique recording ID |
| `RecordingUrl` | URL to audio file |
| `RecordingDuration` | Duration in seconds |
| `RecordingStatus` | `completed`, `failed` |

---

## Say Verb - Text-to-Speech

### Basic Usage

```javascript
const twiml = new Twilio.twiml.VoiceResponse();
twiml.say('Welcome to our service.');
```

### Voice Options

```javascript
twiml.say({
  voice: 'Polly.Amy',        // Amazon Polly voice
  language: 'en-GB',         // Language/accent
  loop: 2                    // Repeat count
}, 'Your message here');
```

### Popular Polly Voices

| Voice | Language | Gender | Style |
|-------|----------|--------|-------|
| `Polly.Amy` | British English | Female | Professional |
| `Polly.Brian` | British English | Male | Authoritative |
| `Polly.Joanna` | US English | Female | Conversational |
| `Polly.Matthew` | US English | Male | Conversational |
| `Polly.Ivy` | US English | Female | Child |
| `Polly.Kendra` | US English | Female | Newscaster |
| `Polly.Salli` | US English | Female | Soft |
| `Polly.Joey` | US English | Male | Casual |
| `Polly.Camila` | Brazilian Portuguese | Female | Neural |
| `Polly.Lupe` | US Spanish | Female | Newscaster |

### SSML for Advanced Speech

```javascript
// Use SSML for control over pronunciation
twiml.say({
  voice: 'Polly.Amy'
}, '<speak>Your order number is <say-as interpret-as="digits">12345</say-as>. ' +
   'It will arrive on <say-as interpret-as="date" format="mdy">12/25/2024</say-as>. ' +
   '<break time="500ms"/>Thank you!</speak>');
```

---

## Gather Verb - Input Collection

### DTMF Input

```javascript
const twiml = new Twilio.twiml.VoiceResponse();
const gather = twiml.gather({
  input: 'dtmf',
  numDigits: 4,           // Exactly 4 digits
  timeout: 5,             // Wait 5 seconds
  finishOnKey: '#',       // End on # key
  action: '/handle-pin',  // POST results here
  method: 'POST'
});
gather.say('Please enter your 4-digit PIN.');
// If no input, fall through to next instruction
twiml.say('No input received.');
twiml.redirect('/start');
```

### Speech Input

```javascript
const gather = twiml.gather({
  input: 'speech',
  speechTimeout: 'auto',           // Auto-detect end of speech
  speechModel: 'phone_call',       // Optimized for phone audio
  language: 'en-US',
  hints: 'yes, no, maybe, cancel', // Improve recognition
  action: '/handle-speech'
});
gather.say('Please say yes or no.');
```

### Combined DTMF + Speech

```javascript
const gather = twiml.gather({
  input: 'dtmf speech',
  timeout: 5,
  numDigits: 1,
  hints: 'one, two, three, sales, support',
  action: '/handle-input'
});
gather.say('Press 1 or say "sales". Press 2 or say "support".');
```

### Handling Gather Results

```javascript
// In /handle-input handler
const digits = event.Digits;
const speech = event.SpeechResult;
const confidence = parseFloat(event.Confidence || '0');

if (digits === '1' || (speech && speech.toLowerCase().includes('sales'))) {
  // Route to sales
} else if (digits === '2' || (speech && speech.toLowerCase().includes('support'))) {
  // Route to support
} else {
  // Unrecognized input
}
```

### Partial Results (Streaming)

```javascript
const gather = twiml.gather({
  input: 'speech',
  partialResultCallback: '/partial-speech',
  partialResultCallbackMethod: 'POST',
  action: '/final-speech'
});
```

---

## Dial Verb - Connecting Calls

### Basic Call Forwarding

```javascript
const twiml = new Twilio.twiml.VoiceResponse();
const dial = twiml.dial({
  callerId: event.To,        // Use original called number
  timeout: 20,               // Ring for 20 seconds
  action: '/dial-status'     // Called when dial ends
});
dial.number('+14155551234');
// If dial fails/times out, fall through
twiml.say('Sorry, no one is available. Please try again later.');
```

### Call with Recording

```javascript
const dial = twiml.dial({
  callerId: event.To,
  record: 'record-from-answer-dual',  // Record both legs separately
  recordingStatusCallback: '/recording-complete',
  recordingStatusCallbackMethod: 'POST',
  recordingStatusCallbackEvent: 'completed'
});
dial.number('+14155551234');
```

### Recording Options

| Value | Description |
|-------|-------------|
| `do-not-record` | No recording (default) |
| `record-from-answer` | Start when answered, single file |
| `record-from-ringing` | Start when ringing |
| `record-from-answer-dual` | Separate files per leg |
| `record-from-ringing-dual` | Separate files, from ringing |

### Simultaneous Ringing (Ring All)

```javascript
const dial = twiml.dial({
  callerId: event.To,
  timeout: 30
});
// All numbers ring simultaneously, first to answer wins
dial.number('+14155551111');
dial.number('+14155552222');
dial.number('+14155553333');
```

### Sequential Ringing (Ring One at a Time)

```javascript
// This requires multiple webhooks - can't do sequential in single TwiML
// Use action callback to try next number on failure
const dial = twiml.dial({
  callerId: event.To,
  timeout: 15,
  action: '/try-next-agent'  // Called when dial ends
});
dial.number('+14155551111');  // Try first
```

### Dial to SIP

```javascript
const dial = twiml.dial({
  callerId: event.From
});
dial.sip({
  username: 'user',
  password: 'pass'
}, 'sip:agent@pbx.company.com');
```

### Dial to Twilio Client

```javascript
const dial = twiml.dial({
  callerId: event.From
});
dial.client('agent-browser-app');  // Client identity
```

### Caller ID Manipulation

```javascript
// Use the original TO number (your Twilio number)
dial.callerId = event.To;

// Use specific caller ID (must be verified or your number)
dial.callerId = '+14155559999';

// For SIP, can use any string
dial.sip({}, 'sip:agent@pbx.com').callerId = 'Support Line';
```

---

## Conference Calls

### Basic Conference

```javascript
const twiml = new Twilio.twiml.VoiceResponse();
const dial = twiml.dial();
dial.conference('room-123');
```

### Moderated Conference

```javascript
// Host joins
const dial = twiml.dial();
dial.conference({
  startConferenceOnEnter: true,  // Conference starts when this caller joins
  endConferenceOnExit: true,     // Conference ends when this caller leaves
  muted: false,
  beep: 'true'                   // Beep when others join
}, 'team-standup');

// Participants join (waiting for host)
dial.conference({
  startConferenceOnEnter: false,  // Wait for host
  endConferenceOnExit: false,
  muted: false,
  waitUrl: '/hold-music'          // Play while waiting
}, 'team-standup');
```

### Conference with Recording

```javascript
dial.conference({
  record: 'record-from-start',
  recordingStatusCallback: '/conference-recording-complete',
  trim: 'trim-silence'            // Trim silence from start/end
}, 'recorded-meeting');
```

### Coach/Whisper (Listen-only)

```javascript
// Agent is in conference normally
dial.conference({
  muted: false
}, 'support-call-123');

// Supervisor joins to coach (can hear both, only agent hears them)
dial.conference({
  muted: false,
  coach: 'CAxxxxx'  // CallSid of agent to coach
}, 'support-call-123');
```

### Conference Events Callback

```javascript
dial.conference({
  statusCallback: '/conference-events',
  statusCallbackEvent: 'start end join leave mute hold speaker',
  statusCallbackMethod: 'POST'
}, 'team-call');
```

---

## Call Recording

### Record with Transcription

```javascript
const twiml = new Twilio.twiml.VoiceResponse();
twiml.say('Please leave a message after the beep.');
twiml.record({
  maxLength: 120,                    // Max 2 minutes
  timeout: 5,                        // Silence timeout
  transcribe: true,
  transcribeCallback: '/transcription-ready',
  action: '/recording-complete',
  playBeep: true,
  trim: 'trim-silence'
});
// Fallback if no recording
twiml.say('No message recorded.');
twiml.hangup();
```

### Recording Attributes

| Attribute | Description |
|-----------|-------------|
| `maxLength` | Max seconds (default 3600) |
| `timeout` | Silence before stopping (default 5) |
| `finishOnKey` | Key to stop recording |
| `transcribe` | Enable transcription |
| `playBeep` | Play beep before recording |
| `trim` | `trim-silence`, `do-not-trim` |

### Access Recording via REST API

```javascript
// In recording callback handler
const recordingSid = event.RecordingSid;
const recordingUrl = event.RecordingUrl;

// Download recording (add .mp3 or .wav)
// https://api.twilio.com/2010-04-01/Accounts/{AccountSid}/Recordings/{RecordingSid}.mp3

// Delete recording after processing
const client = context.getTwilioClient();
await client.recordings(recordingSid).remove();
```

---

## Outbound Calls (REST API)

### Make Outbound Call

```javascript
const client = context.getTwilioClient();

const call = await client.calls.create({
  to: '+14155551234',
  from: context.TWILIO_PHONE_NUMBER,
  url: 'https://your-service.twil.io/outbound-twiml',
  statusCallback: 'https://your-service.twil.io/call-status',
  statusCallbackEvent: ['initiated', 'ringing', 'answered', 'completed'],
  statusCallbackMethod: 'POST'
});

console.log('Call SID:', call.sid);
```

### With Machine Detection

```javascript
const call = await client.calls.create({
  to: '+14155551234',
  from: context.TWILIO_PHONE_NUMBER,
  url: 'https://your-service.twil.io/outbound-twiml',
  machineDetection: 'DetectMessageEnd',  // Wait for beep
  asyncAmd: true,                         // Non-blocking detection
  asyncAmdStatusCallback: '/amd-result',
  asyncAmdStatusCallbackMethod: 'POST'
});
```

### Machine Detection Results

| AnsweredBy | Description |
|------------|-------------|
| `human` | Human answered |
| `machine_start` | Machine, detected at pickup |
| `machine_end_beep` | Machine, after beep |
| `machine_end_silence` | Machine, after silence |
| `machine_end_other` | Machine, detection complete |
| `fax` | Fax machine |
| `unknown` | Detection failed |

### Modify In-Progress Call

```javascript
// Redirect call to new TwiML
await client.calls(callSid).update({
  url: 'https://your-service.twil.io/new-instructions',
  method: 'POST'
});

// End call
await client.calls(callSid).update({
  status: 'completed'
});

// Put on hold with music
await client.calls(callSid).update({
  url: 'https://your-service.twil.io/hold-music'
});
```

---

## Call Queues

### Add Caller to Queue

```javascript
const twiml = new Twilio.twiml.VoiceResponse();
twiml.say('All agents are busy. Please hold.');
twiml.enqueue({
  waitUrl: '/queue-wait',              // TwiML while waiting
  waitUrlMethod: 'POST',
  action: '/queue-exit',               // Called when dequeued
  workflowSid: 'WWxxxxxxxx'            // TaskRouter workflow (optional)
}, 'support-queue');
```

### Queue Wait TwiML

```javascript
// /queue-wait endpoint
exports.handler = function(context, event, callback) {
  const twiml = new Twilio.twiml.VoiceResponse();
  twiml.say(`You are caller number ${event.QueuePosition}. Estimated wait: ${event.AvgQueueTime} seconds.`);
  twiml.play({
    loop: 0  // Loop indefinitely
  }, 'https://api.twilio.com/cowbell.mp3');
  callback(null, twiml);
};
```

### Agent Picks Up from Queue

```javascript
// Agent interface dequeues caller
const twiml = new Twilio.twiml.VoiceResponse();
const dial = twiml.dial();
dial.queue('support-queue');  // Connect to next caller in queue
```

### Queue REST API

```javascript
const client = context.getTwilioClient();

// Get queue stats
const queue = await client.queues('QUxxxxxxxx').fetch();
console.log('Current size:', queue.currentSize);
console.log('Average wait:', queue.averageWaitTime);

// List members in queue
const members = await client.queues('QUxxxxxxxx').members.list();
for (const member of members) {
  console.log(member.callSid, member.position, member.waitTime);
}

// Remove specific caller from queue
await client.queues('QUxxxxxxxx').members(callSid).update({
  url: 'https://your-service.twil.io/dequeued'
});
```

---

## Status Callbacks

### Setting Up Status Callbacks

```javascript
// On outbound call
const call = await client.calls.create({
  to: '+14155551234',
  from: context.TWILIO_PHONE_NUMBER,
  url: '/twiml',
  statusCallback: '/call-events',
  statusCallbackEvent: ['initiated', 'ringing', 'answered', 'completed'],
  statusCallbackMethod: 'POST'
});
```

### Status Callback Handler

```javascript
exports.handler = function(context, event, callback) {
  const callSid = event.CallSid;
  const status = event.CallStatus;
  const duration = event.CallDuration;

  console.log(`Call ${callSid}: ${status}`);

  switch (status) {
    case 'initiated':
      // Call started
      break;
    case 'ringing':
      // Phone is ringing
      break;
    case 'answered':
    case 'in-progress':
      // Call connected
      break;
    case 'completed':
      // Call ended normally
      console.log(`Duration: ${duration} seconds`);
      break;
    case 'busy':
    case 'no-answer':
    case 'failed':
    case 'canceled':
      // Call did not connect
      break;
  }

  callback(null, '');  // Empty response
};
```

---

## Media Streams (Real-Time Audio)

### Start Media Stream

```javascript
const twiml = new Twilio.twiml.VoiceResponse();
const connect = twiml.connect();
connect.stream({
  url: 'wss://your-server.com/audio-stream',
  track: 'both_tracks'  // 'inbound_track', 'outbound_track', 'both_tracks'
});
```

### Stream Events (WebSocket)

Your WebSocket server receives:

```json
{
  "event": "connected",
  "protocol": "Call",
  "version": "1.0.0"
}

{
  "event": "start",
  "sequenceNumber": "1",
  "start": {
    "streamSid": "MZxxxxxxxx",
    "accountSid": "ACxxxxxxxx",
    "callSid": "CAxxxxxxxx",
    "tracks": ["inbound"],
    "mediaFormat": {
      "encoding": "audio/x-mulaw",
      "sampleRate": 8000,
      "channels": 1
    }
  }
}

{
  "event": "media",
  "sequenceNumber": "2",
  "media": {
    "track": "inbound",
    "chunk": "1",
    "timestamp": "5",
    "payload": "base64-encoded-audio..."
  }
}

{
  "event": "stop",
  "sequenceNumber": "100",
  "stop": {
    "accountSid": "ACxxxxxxxx",
    "callSid": "CAxxxxxxxx"
  }
}
```

---

## Pay Verb (PCI Compliant Payments)

### Capture Credit Card

```javascript
const twiml = new Twilio.twiml.VoiceResponse();
twiml.pay({
  chargeAmount: '19.99',
  currency: 'usd',
  paymentConnector: 'Stripe_Connector',  // Configured in Console
  action: '/payment-complete',
  statusCallback: '/payment-status',
  tokenType: 'one-time'
});
```

### Payment Status Handling

```javascript
// Payment callback parameters
// PaymentConfirmationCode - Transaction ID
// Result - 'success' or 'payment-connector-error'
// PaymentCardNumber - Last 4 digits
// PaymentCardType - 'visa', 'mastercard', etc.
```

---

## Common Patterns

### Multi-Level IVR Menu

```javascript
// Main menu
function mainMenu(twiml) {
  const gather = twiml.gather({
    numDigits: 1,
    action: '/ivr/main-handler'
  });
  gather.say('Press 1 for sales. Press 2 for support. Press 0 for operator.');
  twiml.redirect('/ivr/main');  // No input, repeat
}

// Handler
exports.handler = function(context, event, callback) {
  const twiml = new Twilio.twiml.VoiceResponse();
  const digit = event.Digits;

  switch(digit) {
    case '1':
      twiml.redirect('/ivr/sales');
      break;
    case '2':
      twiml.redirect('/ivr/support');
      break;
    case '0':
      twiml.dial().number('+14155551234');
      break;
    default:
      twiml.say('Invalid selection.');
      twiml.redirect('/ivr/main');
  }
  callback(null, twiml);
};
```

### Warm Transfer (Announced)

```javascript
// Step 1: Put caller on hold
twiml.say('Please hold while I transfer you.');
twiml.enqueue({
  waitUrl: '/hold-music'
}, 'transfer-hold');

// Step 2: Agent calls target (separate call)
const client = context.getTwilioClient();
const consultCall = await client.calls.create({
  to: '+14155559999',
  from: context.TWILIO_PHONE_NUMBER,
  url: '/announce-transfer'  // "You have a call from..."
});

// Step 3: If target accepts, dequeue caller to conference
```

### Cold Transfer (Immediate)

```javascript
const twiml = new Twilio.twiml.VoiceResponse();
twiml.say('Transferring you now.');
twiml.dial({
  callerId: event.From  // Keep original caller ID
}).number('+14155559999');
```

### Call Screening

```javascript
// Outbound TwiML asks recipient to accept
twiml.gather({
  numDigits: 1,
  action: '/screen-response'
}).say('You have a call from John Smith. Press 1 to accept, 2 to send to voicemail.');
twiml.redirect('/voicemail');  // No response = voicemail

// If accepted, connect via conference
```

### After-Hours Routing

```javascript
function isBusinessHours() {
  const now = new Date();
  const hour = now.getHours();
  const day = now.getDay();
  // Mon-Fri 9-5
  return day >= 1 && day <= 5 && hour >= 9 && hour < 17;
}

exports.handler = function(context, event, callback) {
  const twiml = new Twilio.twiml.VoiceResponse();

  if (isBusinessHours()) {
    twiml.redirect('/business-hours-ivr');
  } else {
    twiml.say('Our office is currently closed. Office hours are Monday through Friday, 9 AM to 5 PM.');
    twiml.say('Please leave a message after the beep.');
    twiml.record({
      maxLength: 120,
      action: '/voicemail-saved'
    });
  }
  callback(null, twiml);
};
```

---

## TwiML Control Model

**Critical**: In almost all cases, only ONE TwiML document controls a call at any given time.

### Exception: Background Operations

Some TwiML verbs start background processes that continue running even after the call moves to subsequent TwiML documents:

- **`<Start><Stream>`** - Media streaming continues in the background
- **`<Start><Recording>`** - Recording continues until explicitly stopped
- **`<Start><Siprec>`** - SIPREC streaming continues in the background

```javascript
// Recording starts and continues through subsequent TwiML
const start = twiml.start();
start.recording({
  recordingStatusCallback: '/recording-complete',
  recordingStatusCallbackEvent: 'completed',
});
twiml.say('This is being recorded...');
twiml.redirect('/next-handler'); // Recording continues!
```

> **Note**: The method is `.recording()`, NOT `.record()`. `twiml.start().recording({...})` is correct.

### Key Implications

1. **Updating participant TwiML exits current state**: If a participant is in a conference and you update their call with new TwiML, they immediately exit the conference and execute the new TwiML.

2. **Conference teardown risk**: If the exiting participant had `endConferenceOnExit=true`, the entire conference tears down — appearing as a "dropped call" to other participants.

3. **Call transfer in conference context**: "Transfer" means adding a new participant to the existing conference, NOT replacing TwiML.

### Safe Conference Transfer Pattern

```javascript
// Add specialist to existing conference (they join, nobody leaves)
await client.conferences('support-12345')
  .participants
  .create({
    from: context.TWILIO_PHONE_NUMBER,
    to: specialistNumber,
    startConferenceOnEnter: true,
    endConferenceOnExit: false
  });

// Agent can drop off by removing their participant:
await client.conferences('support-12345')
  .participants(agentCallSid)
  .update({ status: 'completed' });
```

### Dangerous Pattern (Avoid)

```javascript
// DON'T: Update participant with new TwiML - exits them from conference
await client.calls(participantCallSid)
  .update({
    twiml: '<Response><Dial>+15551234567</Dial></Response>'
  });
// This removes them from conference and may tear it down!
```

---

## Conference via REST API (Preferred)

Use the Conferences Participants API for programmatic control:

```javascript
// Create conference by adding first participant
const participant = await client.conferences('my-conference')
  .participants
  .create({
    from: context.TWILIO_PHONE_NUMBER,
    to: participantNumber,
    timeout: 30,
    timeLimit: 600,
    startConferenceOnEnter: true,
    endConferenceOnExit: false,
    muted: false,
    beep: true
  });

// Add additional participants
await client.conferences('my-conference')
  .participants
  .create({
    from: context.TWILIO_PHONE_NUMBER,
    to: anotherParticipant,
    timeout: 30,
    timeLimit: 600
  });

// End conference
await client.conferences(conferenceSid)
  .update({ status: 'completed' });
```

### Finding Conferences by Name

```javascript
const conferences = await client.conferences.list({
  friendlyName: 'my-conference',
  status: 'in-progress',
  limit: 1
});

if (conferences.length > 0) {
  const conference = conferences[0];
  console.log(`SID: ${conference.sid}`);
}
```

---

## Logging and Response Rules

Twilio Functions generate debugger alerts based on log level:

| Log Level | Alert Code | Effect |
|-----------|------------|--------|
| `console.log` | None | Silent — use for all operational logging |
| `console.warn` | 82004 | Generates warning alert — avoid |
| `console.error` | 82005 | Generates error alert — avoid |

Use `console.log` for **all** logging, including error conditions and catch blocks.

**Response bodies**: Always pass a string to `Twilio.Response.setBody()`, not a plain object. Use `JSON.stringify()` and set `Content-Type: application/json`. Passing an object causes `Buffer.from(object)` TypeError in the runtime.

```javascript
// WRONG — triggers Buffer TypeError
response.setBody({ success: true });

// RIGHT — explicit JSON serialization
response.appendHeader('Content-Type', 'application/json');
response.setBody(JSON.stringify({ success: true }));
```

---

---

## Gotchas

### Conference Participants API vs TwiML Conference

The Participants API and TwiML Conference verb have different parameter formats:

| Parameter | Participants API | TwiML Conference |
|-----------|-----------------|---------------------|
| Record / record | Boolean: true or false | String: record-from-start, record-from-answer, etc. |

Passing TwiML values to the Participants API (e.g., Record: record-from-start) returns HTTP 400.

### Recording Callback URLs Must Be Absolute

Start Recording requires absolute callback URLs. Relative paths trigger error 11200. The recording completes, but the status callback never fires.

### Dial action URL Should Not Be the Inbound Handler

When Dial action is set to the same handler, it fires again after the Dial completes. If the handler creates one-time resources, the second invocation produces errors. Use a dedicated Dial-complete handler.

### Conference Recording Captures Hold Music

When using Record=true on the Conference Participants API, recording starts from conference creation. Hold music before the agent joins is recorded. Transcripts get dominated by music tags.

### Avoid Duplicate Recordings

Do not combine --record CLI flag with Start Recording TwiML. This creates two recordings (one OutboundAPI 1-channel, one TwiML 2-channel). Pick one method.

---

## File Naming Conventions

| Suffix | Access Level | Use Case |
|--------|--------------|----------|
| `.js` | Public | General endpoints, health checks |
| `.protected.js` | Twilio Only | Webhooks (validates signature) |
| `.private.js` | Internal | Helper functions, not HTTP accessible |

---

## Testing Voice Functions

### Unit Test TwiML Generation

```javascript
const { handler } = require('../functions/voice/incoming-call');

describe('incoming-call', () => {
  it('returns valid TwiML with greeting', async () => {
    const context = { /* mock context */ };
    const event = { From: '+14155551234', To: '+14155559876' };

    const result = await new Promise((resolve) => {
      handler(context, event, (err, response) => {
        resolve(response.toString());
      });
    });

    expect(result).toContain('<Say');
    expect(result).toContain('<Gather');
  });
});
```

### Integration Test (Make Real Call)

```javascript
const client = require('twilio')(accountSid, authToken);

const call = await client.calls.create({
  to: testPhoneNumber,
  from: twilioPhoneNumber,
  url: `${baseUrl}/voice/test-endpoint`
});

// Wait and check call status
await new Promise(r => setTimeout(r, 10000));
const callDetails = await client.calls(call.sid).fetch();
expect(callDetails.status).toBe('completed');
```
