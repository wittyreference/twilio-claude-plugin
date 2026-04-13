---
name: "media-streams"
description: "Twilio development skill: media-streams"
---

---
name: media-streams
description: Twilio Media Streams WebSocket guide. Use when building voice AI with custom STT/TTS, real-time audio processing, bidirectional audio, or <Connect><Stream> integration.
---

# Media Streams Skill

Guide for Twilio Media Streams (`<Connect><Stream>`) — raw audio WebSocket integration for bring-your-own STT/TTS. Load this skill when building voice AI with custom speech processing, real-time audio analysis, or third-party STT/TTS engines.

---

## When to Use Media Streams vs ConversationRelay

| Criteria | Media Streams | ConversationRelay |
|----------|:------------:|:-----------------:|
| Audio access | Raw mulaw 8kHz frames | No audio — text in/out |
| STT/TTS | Bring your own | Built-in (Google, Polly) |
| Protocol complexity | High (binary audio) | Low (JSON text) |
| Latency control | Full | Twilio-managed |
| DTMF detection | Bidirectional only | Built-in |
| Interruption handling | Manual | Built-in |
| Custom audio processing | Yes (analysis, effects) | No |
| Time to prototype | Longer | Shorter |

**Use Media Streams when:** you need raw audio access, custom STT/TTS engines, real-time audio analysis (sentiment from tone, speaker diarization), or integration with platforms that expect audio input (Google Cloud Speech, AWS Transcribe, Azure Speech).

**Use ConversationRelay when:** you want text-based LLM integration with minimal audio plumbing. ConversationRelay handles STT, TTS, interruptions, and barge-in automatically.

---

## TwiML Setup

### Bidirectional Stream (`<Connect><Stream>`)

Bidirectional streams allow both receiving and sending audio. The `<Connect>` verb blocks subsequent TwiML until the stream ends.

```javascript
const twiml = new Twilio.twiml.VoiceResponse();

// Optional: start background recording before stream
const start = twiml.start();
start.recording({
  recordingStatusCallback: `https://${context.DOMAIN_NAME}/callbacks/call-status`,
  recordingStatusCallbackEvent: 'completed',
});

twiml.say({ voice: 'Polly.Amy' }, 'Connecting you to our assistant.');

const connect = twiml.connect();
connect.stream({
  url: 'wss://your-server.com/audio-stream',
  // Optional: pass custom parameters to the WebSocket
  // name: 'my-stream',
});

return callback(null, twiml);
```

### Stream Attributes

| Attribute | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `url` | string | Yes | WebSocket URL (`wss://`) to connect to |
| `name` | string | No | Friendly name for the stream |
| `track` | string | No | `inbound_track`, `outbound_track`, `both_tracks` (unidirectional only) |
| `statusCallback` | string | No | URL for stream lifecycle events |
| `statusCallbackMethod` | string | No | HTTP method for status callback |

### Custom Parameters

Pass context to your WebSocket handler via `<Parameter>`:

```javascript
const connect = twiml.connect();
const stream = connect.stream({
  url: 'wss://your-server.com/audio-stream',
});
stream.parameter({ name: 'callerNumber', value: event.From });
stream.parameter({ name: 'language', value: 'en-US' });
```

Parameters arrive in the `start` message's `customParameters` object.

### Unidirectional Stream (`<Start><Stream>`)

Unidirectional streams run in the background — subsequent TwiML continues executing.

```javascript
const twiml = new Twilio.twiml.VoiceResponse();

// Stream runs in background while call continues
const start = twiml.start();
start.stream({
  url: 'wss://your-server.com/listen',
  track: 'both_tracks',
});

// Call continues with normal TwiML
twiml.say('Your call is being analyzed.');
twiml.dial('+15559876543');

return callback(null, twiml);
```

---

## WebSocket Protocol

The WebSocket protocol defines message types for both directions: Twilio sends `connected`, `start`, `media`, `dtmf`, `mark`, and `stop` events to your server; your server can send `media` (audio), `mark` (playback tracking), and `clear` (interrupt) messages back to Twilio.

See [references/protocol-reference.md](references/protocol-reference.md) for the full WebSocket message format specification.

---

## WebSocket Server Template (Node.js)

```javascript
const WebSocket = require('ws');
const http = require('http');

const server = http.createServer();
const wss = new WebSocket.Server({ server });

wss.on('connection', (ws) => {
  let streamSid = null;

  ws.on('message', (data) => {
    const msg = JSON.parse(data);

    switch (msg.event) {
      case 'connected':
        console.log('Stream connected');
        break;

      case 'start':
        streamSid = msg.start.streamSid;
        console.log(`Stream started: ${streamSid}`);
        console.log(`Call SID: ${msg.start.callSid}`);
        console.log(`Custom params:`, msg.start.customParameters);
        break;

      case 'media':
        // msg.media.payload is base64 mulaw audio
        // Send to your STT engine here
        handleAudio(msg.media.payload, msg.media.timestamp);
        break;

      case 'dtmf':
        console.log(`DTMF: ${msg.dtmf.digit}`);
        break;

      case 'mark':
        console.log(`Mark reached: ${msg.mark.name}`);
        break;

      case 'stop':
        console.log('Stream stopped');
        break;
    }
  });

  ws.on('close', () => {
    console.log('WebSocket closed');
  });

  // Send audio back to the caller (bidirectional)
  function sendAudio(base64Audio) {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({
        event: 'media',
        streamSid,
        media: { payload: base64Audio },
      }));
    }
  }

  // Interrupt current playback
  function clearAudio() {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({
        event: 'clear',
        streamSid,
      }));
    }
  }
});

server.listen(8080, () => console.log('Stream server on :8080'));
```

---

## Audio Encoding

### Format Specification

| Property | Value |
|----------|-------|
| Encoding | G.711 mu-law (mulaw) |
| Sample rate | 8000 Hz |
| Channels | 1 (mono) |
| Bit depth | 8 bits per sample |
| Container | None (raw samples, base64-encoded) |

### Converting Audio for Playback

To send audio back via bidirectional stream, convert to mulaw 8kHz first:

```bash
# Using ffmpeg
ffmpeg -i input.mp3 -ar 8000 -ac 1 -f mulaw output.raw

# Using sox
sox input.wav -r 8000 -c 1 -e mu-law -t raw output.raw
```

Then base64-encode the raw bytes before sending.

### Decoding Received Audio

```javascript
// Decode base64 payload to raw mulaw bytes
const mulawBuffer = Buffer.from(msg.media.payload, 'base64');

// Convert mulaw to PCM 16-bit for STT engines that expect linear PCM
function mulawToPcm16(mulawByte) {
  // Standard mu-law expansion table lookup
  // Most STT SDKs accept mulaw directly — check your provider first
}
```

---

## STT/TTS Integration Patterns

### Google Cloud Speech-to-Text

```javascript
const speech = require('@google-cloud/speech');
const client = new speech.SpeechClient();

// Create streaming recognition
const recognizeStream = client.streamingRecognize({
  config: {
    encoding: 'MULAW',
    sampleRateHertz: 8000,
    languageCode: 'en-US',
    enableAutomaticPunctuation: true,
  },
  interimResults: true,
});

// In media handler:
recognizeStream.write(Buffer.from(msg.media.payload, 'base64'));

// On transcript result:
recognizeStream.on('data', (data) => {
  const transcript = data.results[0]?.alternatives[0]?.transcript;
  if (data.results[0]?.isFinal) {
    // Send to LLM, get response, convert to audio, send back
  }
});
```

### Amazon Transcribe Streaming

```javascript
const { TranscribeStreamingClient, StartStreamTranscriptionCommand } = require('@aws-sdk/client-transcribe-streaming');

const client = new TranscribeStreamingClient({ region: 'us-east-1' });

// Amazon Transcribe expects PCM — convert mulaw to PCM first
// Or use a library like 'alawmulaw' for conversion
```

---

## Constraints and Limitations

### Bidirectional Streams (`<Connect><Stream>`)

| Constraint | Detail |
|-----------|--------|
| Streams per call | 1 |
| TwiML execution | Blocks — no subsequent verbs execute |
| Ending the stream | Only by ending the call (hangup or REST API update) |
| DTMF | Supported (inbound only) |
| Audio direction | Receive inbound, send outbound |

### Unidirectional Streams (`<Start><Stream>`)

| Constraint | Detail |
|-----------|--------|
| Streams per call | Up to 4 tracks |
| TwiML execution | Non-blocking — subsequent verbs continue |
| Ending the stream | `<Stop><Stream>` TwiML or REST API |
| DTMF | Not supported |
| Audio direction | Receive only (inbound, outbound, or both) |

### General Constraints

- WebSocket URL must use `wss://` (secure WebSocket)
- Media packets arrive approximately every 20ms (160 bytes of mulaw = 20ms of audio)
- No built-in reconnection — if WebSocket drops, stream ends
- Cannot mix `<Connect><Stream>` with `<Connect><ConversationRelay>` on the same call
- Firewall: allow TCP 443 from Twilio IP ranges

---

## Backpressure and Audio Buffering

Media packets arrive every ~20ms (160 bytes of mulaw per packet = 8KB/s per stream). If your processing pipeline (STT inference, audio analysis) cannot keep up, packets queue in the WebSocket buffer.

**Detecting lag:**
- Node.js `ws` library: monitor `ws.bufferedAmount`. Values above 64KB (~8 seconds of audio) indicate the consumer is falling behind.
- Track the `timestamp` field in media messages. If the gap between the packet timestamp and wall-clock time exceeds your latency budget (typically 1-3 seconds for real-time STT), you are lagging.

**Backpressure strategies:**
- **Drop oldest frames**: For real-time STT, stale audio is useless. Maintain a ring buffer of the last N packets and discard older ones when the processing queue exceeds a threshold. This preserves the most recent speech context.
- **Adaptive quality**: Reduce STT model complexity or switch to a lighter model when lag is detected. For example, switch from a large Whisper model to a streaming Deepgram endpoint during peak load.
- **Horizontal scaling**: Route new WebSocket connections to additional server instances. Each bidirectional stream is independent — no shared state between streams — so horizontal scaling requires no sticky sessions.

**STT provider considerations:**
- Google Cloud Speech streaming has its own flow control. If you send audio faster than it can process, interim results lag but audio is not lost. Monitor `data.results[0].resultEndTime` relative to stream elapsed time.
- Deepgram streaming accepts audio as fast as you send it but interim results may lag under load. Monitor the `start` field in transcript messages.
- Amazon Transcribe streaming has a 15-second buffer. If your pipeline falls 15+ seconds behind, the stream is terminated.

---

## Scaling Concurrent Streams

Each active call with a bidirectional stream requires one persistent WebSocket connection. N concurrent calls = N WebSocket connections to your server.

**Single-server capacity:**
- Node.js: practical limit of ~1,000-5,000 concurrent WebSocket connections per process, depending on per-connection CPU usage (audio processing is CPU-bound, not I/O-bound).
- Python (asyncio/websockets): similar range, but GIL limits CPU-bound audio processing to one core per process. Use multiprocessing for CPU-heavy STT.
- Go: higher raw connection capacity (~10,000+) due to goroutine efficiency, but STT inference is still the bottleneck.

**Horizontal scaling:**
- Use a load balancer with WebSocket support (ALB, nginx with `proxy_pass` + `Upgrade` headers, or Cloudflare).
- Sticky sessions are NOT required — each WebSocket connection is independent with no shared state.
- Scale based on concurrent connection count, not request rate. Monitor active WebSocket connections as the primary scaling metric.

**Cost scaling:**
- Each concurrent stream requires a separate streaming recognition session with your STT provider. Google charges per 15-second increment. Deepgram charges per audio-hour. Budget for N concurrent sessions at peak.
- Twilio charges per-minute for the call itself. The stream adds no additional Twilio charge beyond the call cost.

**Twilio-side limits:**
- No documented per-account limit on concurrent streams specifically. Subject to your account's concurrent call limit.
- If you need more than your default concurrent call limit, request an increase through Twilio support or your account team.

---

## Gotchas

### Media Streams ≠ ConversationRelay

A ConversationRelay WebSocket handler **cannot** be used with `<Stream>`. ConversationRelay sends structured JSON (`{ type: "prompt" }`); Media Streams sends raw audio frames (`{ event: "media" }`). Connecting the wrong handler type causes immediate disconnection with no error.

### `<Connect><Stream>` Blocks TwiML

Once `<Connect><Stream>` starts, no subsequent TwiML executes. Place `<Say>`, `<Start><Recording>`, or other setup verbs **before** `<Connect>`.

### Cannot Stop a Bidirectional Stream Without Ending the Call

There is no `<Stop><Stream>` for bidirectional streams. The only way to end a `<Connect><Stream>` is to end the call via REST API (`client.calls(callSid).update({ status: 'completed' })`) or the caller hanging up.

### No File Headers in Outbound Audio

Audio sent back must be raw mulaw samples, base64-encoded. Do NOT include WAV headers, MP3 frames, or any container format. The audio will play as noise/static if headers are present.

### 20ms Packet Cadence

Media arrives in ~20ms chunks (160 mulaw samples per packet). STT engines that expect continuous streams need buffering. Engines that expect discrete utterances need silence detection.

### Unidirectional Streams Cannot Send Audio

`<Start><Stream>` is receive-only. If you need to play audio back to the caller, use `<Connect><Stream>` (bidirectional) instead.

### Stream URL Must Be Absolute

Relative WebSocket URLs are not supported. Always use a full `wss://` URL.

### Recording + Stream Independence

`<Start><Recording>` and `<Start><Stream>` are independent background operations. Recording captures the full call audio; the stream provides a real-time copy. Both can run simultaneously.

### WebSocket Hang vs Drop

A WebSocket **drop** (connection close) is well-documented: the stream ends, `<Connect>` completes, and TwiML execution resumes. A WebSocket **hang** (server stops responding without closing the connection) is different and more dangerous:

- The TCP connection remains open, so Twilio doesn't detect a failure
- `<Connect><Stream>` continues to block TwiML execution
- The caller hears silence indefinitely
- Twilio has no documented ping/pong timeout that would auto-close a hung connection

**Detection (server-side)**: Implement a self-watchdog in your WebSocket server. Track the timestamp of the last processed audio frame. If no frame is processed for >5 seconds despite receiving media events, the processing pipeline is hung. Close the WebSocket connection to trigger Twilio's stream-end behavior.

**Detection (platform-side)**: Monitor call duration. If a Media Streams call exceeds the expected maximum duration, use the REST API to end the call: `calls(callSid).update({ status: 'completed' })`. This is the only way to recover from a hung stream without the caller hanging up.

**Prevention**: Use `setTimeout` or equivalent in your WebSocket handler to detect processing stalls. If your STT/TTS pipeline doesn't respond within N seconds, close the WebSocket gracefully rather than waiting indefinitely.

---

## Reference Implementation

See `stream-connect.js` for the TwiML setup pattern used in this project.
