---
name: messaging
description: Build Twilio SMS/MMS applications with TwiML, webhooks, and status callbacks. Use when handling inbound/outbound text messages, WhatsApp, or MMS.
---

# Messaging Skill

Comprehensive knowledge for building Twilio Messaging applications - SMS, MMS, WhatsApp, and Messaging Services.

## TwiML Messaging Verbs

### Message Verb

```javascript
const twiml = new Twilio.twiml.MessagingResponse();
twiml.message('Your reply text here');
```

### Message with Media (MMS)

```javascript
const twiml = new Twilio.twiml.MessagingResponse();
const message = twiml.message('Check out this image!');
message.media('https://example.com/image.jpg');
// Can add up to 10 media URLs
message.media('https://example.com/image2.jpg');
```

### Redirect Verb

```javascript
const twiml = new Twilio.twiml.MessagingResponse();
twiml.redirect('/messaging/other-handler');
```

### No Reply (Empty Response)

```javascript
// Return empty TwiML to not reply
const twiml = new Twilio.twiml.MessagingResponse();
callback(null, twiml);  // No <Message> = no reply
```

---

## Webhook Parameters

### Inbound SMS Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `MessageSid` | Unique message ID | `SMxxxxxxxx` |
| `AccountSid` | Your Account SID | `ACxxxxxxxx` |
| `From` | Sender's number (E.164) | `+14155551234` |
| `To` | Recipient number (E.164) | `+14155559876` |
| `Body` | Message text content | `Hello!` |
| `NumMedia` | Number of attachments | `0`, `1`, `2` |
| `MediaUrl0` | First attachment URL | `https://...` |
| `MediaContentType0` | First attachment type | `image/jpeg` |
| `FromCity` | Sender's city | `San Francisco` |
| `FromState` | Sender's state | `CA` |
| `FromCountry` | Sender's country | `US` |
| `FromZip` | Sender's ZIP | `94102` |
| `NumSegments` | SMS segment count | `1`, `2`, `3` |
| `SmsMessageSid` | Same as MessageSid | `SMxxxxxxxx` |
| `SmsSid` | Same as MessageSid | `SMxxxxxxxx` |

### Status Callback Parameters

| Parameter | Description |
|-----------|-------------|
| `MessageSid` | Message identifier |
| `MessageStatus` | Current status |
| `To` | Recipient number |
| `From` | Sender number |
| `ErrorCode` | Error code (if failed) |
| `ErrorMessage` | Error description |

### Status Values

| Status | Description |
|--------|-------------|
| `queued` | Message accepted, queued for sending |
| `sending` | Message is being sent |
| `sent` | Message sent to carrier |
| `delivered` | Delivery confirmed by carrier |
| `undelivered` | Carrier rejected message |
| `failed` | Message could not be sent |
| `read` | Message read (WhatsApp only) |

---

## REST API - Sending Messages

### Basic SMS

```javascript
const client = context.getTwilioClient();

const message = await client.messages.create({
  to: '+14155551234',
  from: context.TWILIO_PHONE_NUMBER,
  body: 'Hello from Twilio!'
});

console.log('Message SID:', message.sid);
```

### SMS with Status Callback

```javascript
const message = await client.messages.create({
  to: '+14155551234',
  from: context.TWILIO_PHONE_NUMBER,
  body: 'Hello!',
  statusCallback: 'https://your-service.twil.io/message-status'
});
```

### MMS with Media

```javascript
const message = await client.messages.create({
  to: '+14155551234',
  from: context.TWILIO_PHONE_NUMBER,
  body: 'Check out this image!',
  mediaUrl: [
    'https://example.com/image.jpg',
    'https://example.com/image2.jpg'
  ]
});
```

### Using Messaging Service

```javascript
// Recommended for production - handles sender selection
const message = await client.messages.create({
  to: '+14155551234',
  messagingServiceSid: context.TWILIO_MESSAGING_SERVICE_SID,
  body: 'Hello from Messaging Service!'
});
```

### Scheduled Message

```javascript
// Schedule for future delivery (requires Messaging Service)
const message = await client.messages.create({
  to: '+14155551234',
  messagingServiceSid: context.TWILIO_MESSAGING_SERVICE_SID,
  body: 'Reminder: Your appointment is tomorrow!',
  scheduleType: 'fixed',
  sendAt: new Date('2024-12-25T10:00:00Z')  // ISO 8601 format
});

// Cancel scheduled message
await client.messages(message.sid).update({
  status: 'canceled'
});
```

### Bulk Messaging (Multiple Recipients)

```javascript
// Send to multiple numbers (use Promise.all for parallel)
const numbers = ['+14155551111', '+14155552222', '+14155553333'];

const results = await Promise.all(
  numbers.map(to =>
    client.messages.create({
      to,
      messagingServiceSid: context.TWILIO_MESSAGING_SERVICE_SID,
      body: 'Group announcement!'
    }).catch(err => ({ error: err.message, to }))
  )
);

// Check for failures
const failures = results.filter(r => r.error);
```

---

## Messaging Services

Messaging Services provide intelligent sender selection, compliance features, and scalability.

### Why Use Messaging Services

- **Sender Pool**: Automatically selects best number from pool
- **Sticky Sender**: Same sender for ongoing conversations
- **Geographic Matching**: Uses local numbers when available
- **Compliance**: Built-in opt-out handling
- **Scalability**: Higher throughput with number pools
- **Link Shortening**: Automatic URL shortening and tracking

### Configure via REST API

```javascript
// Create a Messaging Service
const service = await client.messaging.v1.services.create({
  friendlyName: 'My App Notifications',
  inboundRequestUrl: 'https://your-service.twil.io/incoming-sms',
  inboundMethod: 'POST',
  statusCallback: 'https://your-service.twil.io/message-status',
  useInboundWebhookOnNumber: false,  // Use service URL, not number URL
  stickySender: true,
  smartEncoding: true
});

// Add phone numbers to service
await client.messaging.v1.services(service.sid)
  .phoneNumbers
  .create({ phoneNumberSid: 'PNxxxxxxxx' });
```

### Link Shortening

```javascript
const message = await client.messages.create({
  to: '+14155551234',
  messagingServiceSid: context.TWILIO_MESSAGING_SERVICE_SID,
  body: 'Check your order: https://example.com/orders/12345',
  shortenUrls: true  // URLs become twil.io links
});
```

---

## A2P 10DLC (US Application-to-Person Messaging)

For US messaging, A2P 10DLC registration is required for reliable delivery.

### Registration Flow

1. **Register Brand** - Your business identity
2. **Create Campaign** - Use case description
3. **Associate Numbers** - Link phone numbers to campaign

### Trust Scores

| Score | Throughput | Use Case |
|-------|------------|----------|
| Low | 1 msg/sec | Basic verification |
| Medium | 10 msg/sec | Marketing, notifications |
| High | Up to 225+ msg/sec | Large enterprises |

### Gotchas

- Registration can take days/weeks
- Unregistered numbers have very low throughput
- Different campaign types have different requirements
- Opt-in evidence may be required

---

## Opt-Out Handling

### Automatic Opt-Out (Default)

Twilio automatically handles standard opt-out keywords:
- STOP, STOPALL, UNSUBSCRIBE, CANCEL, END, QUIT

### Custom Opt-Out

```javascript
// Check opt-out status before sending
const optOut = await client.messaging.v1.services(messagingServiceSid)
  .phoneNumbers(phoneNumber)
  .fetch();

if (optOut.capabilities.mms) {
  // Number is not opted out, safe to send
}
```

### Handle Opt-In/Opt-Out Webhooks

```javascript
exports.handler = function(context, event, callback) {
  const body = (event.Body || '').toLowerCase().trim();

  if (['stop', 'unsubscribe', 'cancel'].includes(body)) {
    // Twilio auto-responds; log for your records
    console.log(`Opt-out received from ${event.From}`);
    // Update your database
  }

  if (['start', 'yes', 'unstop'].includes(body)) {
    console.log(`Opt-in received from ${event.From}`);
    // Update your database
  }

  callback(null, new Twilio.twiml.MessagingResponse());
};
```

---

## Message Character Limits

### SMS Encoding

| Encoding | Characters | Per Segment | Max Segments |
|----------|------------|-------------|--------------|
| GSM-7 | Standard ASCII | 160 chars | 10 |
| GSM-7 Extended | With special chars | 153 chars | 10 |
| UCS-2 (Unicode) | Emojis, non-Latin | 70 chars | 10 |
| UCS-2 Concatenated | Long Unicode | 67 chars | 10 |

### Characters That Trigger UCS-2

- Emojis (💡, 🎉, etc.)
- Non-Latin scripts (Chinese, Arabic, etc.)
- Some special characters

### Smart Encoding

```javascript
// Let Twilio optimize encoding automatically
const message = await client.messages.create({
  to: '+14155551234',
  messagingServiceSid: context.TWILIO_MESSAGING_SERVICE_SID,
  body: messageText,
  smartEncoded: true  // Twilio optimizes encoding
});
```

### Segment Calculation

```javascript
function calculateSegments(text) {
  // Check for non-GSM characters
  const gsmChars = /^[@£$¥èéùìòÇØøÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ !"#¤%&'()*+,\-./:;<=>?¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà\^{}\[~\]|€\n\r\\]*$/;

  const isGsm = gsmChars.test(text);
  const length = text.length;

  if (isGsm) {
    return length <= 160 ? 1 : Math.ceil(length / 153);
  } else {
    return length <= 70 ? 1 : Math.ceil(length / 67);
  }
}
```

---

## Error Codes

### Common SMS Error Codes

| Code | Description | Solution |
|------|-------------|----------|
| 21211 | Invalid 'To' number | Check E.164 format |
| 21408 | Permission to send not enabled | Enable region/capability |
| 21610 | Message undeliverable | Recipient opted out |
| 21612 | 'To' not a valid mobile | Cannot SMS landlines |
| 21614 | 'To' not SMS-capable | Number doesn't receive SMS |
| 21617 | Message body required | Include body parameter |
| 30003 | Unreachable destination | Carrier/network issue |
| 30004 | Message blocked | Content filtered |
| 30005 | Unknown destination | Invalid phone number |
| 30006 | Landline or unreachable | Not a mobile number |
| 30007 | Carrier violation | A2P compliance issue |
| 30008 | Unknown error | Contact support |

### Error Handling

```javascript
try {
  const message = await client.messages.create({
    to: '+14155551234',
    from: context.TWILIO_PHONE_NUMBER,
    body: 'Hello!'
  });
} catch (error) {
  if (error.code === 21610) {
    // Recipient opted out
    console.log('User has opted out');
  } else if (error.code === 21614) {
    // Not SMS capable
    console.log('Number cannot receive SMS');
  } else if (error.code >= 30000 && error.code < 40000) {
    // Delivery error - may retry
    console.log('Delivery failed:', error.message);
  } else {
    throw error;
  }
}
```

---

## MMS (Multimedia Messaging)

### Supported Media Types

| Type | Max Size | Notes |
|------|----------|-------|
| JPEG/PNG/GIF | 5 MB | Images |
| MP4/3GP | 5 MB | Video |
| MP3/AMR | 5 MB | Audio |
| VCF | 5 MB | Contact cards |
| PDF | 5 MB | Documents |

### Receiving MMS

```javascript
exports.handler = function(context, event, callback) {
  const twiml = new Twilio.twiml.MessagingResponse();
  const numMedia = parseInt(event.NumMedia, 10) || 0;

  if (numMedia > 0) {
    // Process each media attachment
    for (let i = 0; i < numMedia; i++) {
      const mediaUrl = event[`MediaUrl${i}`];
      const mediaType = event[`MediaContentType${i}`];
      console.log(`Media ${i}: ${mediaType} at ${mediaUrl}`);

      // Download and process the media
      // Note: URLs require authentication
    }
    twiml.message(`Received ${numMedia} attachment(s). Processing...`);
  } else {
    twiml.message('No media received.');
  }

  callback(null, twiml);
};
```

### Downloading Media

```javascript
const axios = require('axios');

async function downloadMedia(mediaUrl, accountSid, authToken) {
  const response = await axios.get(mediaUrl, {
    auth: {
      username: accountSid,
      password: authToken
    },
    responseType: 'arraybuffer'
  });

  return {
    data: response.data,
    contentType: response.headers['content-type']
  };
}
```

### Delete Media After Processing

```javascript
// Get message media
const mediaList = await client.messages(messageSid).media.list();

// Delete each media item
for (const media of mediaList) {
  await client.messages(messageSid).media(media.sid).remove();
}
```

---

## WhatsApp

### Sending WhatsApp Messages

```javascript
// WhatsApp numbers use 'whatsapp:' prefix
const message = await client.messages.create({
  to: 'whatsapp:+14155551234',
  from: 'whatsapp:+14155559999',  // Your WhatsApp-enabled number
  body: 'Hello from WhatsApp!'
});
```

### WhatsApp Templates (HSM)

```javascript
// For messages outside 24-hour session window
const message = await client.messages.create({
  to: 'whatsapp:+14155551234',
  from: 'whatsapp:+14155559999',
  contentSid: 'HXxxxxxxxx',  // Pre-approved template
  contentVariables: JSON.stringify({
    1: 'John',
    2: 'Order #12345'
  })
});
```

### WhatsApp Session Rules

- **Session Window**: 24 hours from last user message
- **Within Session**: Send any message
- **Outside Session**: Must use pre-approved template
- **Read Receipts**: WhatsApp provides read status

---

## Common Patterns

### Keyword Routing

```javascript
exports.handler = function(context, event, callback) {
  const twiml = new Twilio.twiml.MessagingResponse();
  const body = (event.Body || '').toLowerCase().trim();
  const firstWord = body.split(' ')[0];

  const handlers = {
    help: () => 'Commands: HELP, STATUS, BALANCE, STOP',
    status: () => 'System operational. No issues.',
    balance: async () => {
      // Lookup balance for this number
      return `Your balance: $25.00`;
    },
    stop: () => null,  // Let Twilio handle opt-out
  };

  const handler = handlers[firstWord];

  if (handler) {
    const response = await handler();
    if (response) twiml.message(response);
  } else {
    twiml.message('Unknown command. Reply HELP for options.');
  }

  callback(null, twiml);
};
```

### Conversational State (URL Parameters)

```javascript
// Pass state via URL parameters
const twiml = new Twilio.twiml.MessagingResponse();
twiml.redirect(`/messaging/step2?state=${encodeURIComponent(JSON.stringify(state))}`);
```

### Rate Limiting

```javascript
// Simple in-memory rate limit (use Redis for production)
const rateLimits = new Map();
const LIMIT = 5;  // Messages per minute
const WINDOW = 60000;  // 1 minute

function checkRateLimit(phoneNumber) {
  const now = Date.now();
  const key = phoneNumber;
  const record = rateLimits.get(key) || { count: 0, resetAt: now + WINDOW };

  if (now > record.resetAt) {
    record.count = 0;
    record.resetAt = now + WINDOW;
  }

  if (record.count >= LIMIT) {
    return false;  // Rate limited
  }

  record.count++;
  rateLimits.set(key, record);
  return true;
}
```

### Conversation Tracking

```javascript
// Use Twilio Sync or database to track conversations
async function getConversation(from, to) {
  const syncService = context.getTwilioClient().sync.v1.services(context.SYNC_SERVICE_SID);

  try {
    const doc = await syncService.documents(`conv-${from}-${to}`).fetch();
    return doc.data;
  } catch (error) {
    if (error.status === 404) {
      // New conversation
      return { messages: [], state: 'new' };
    }
    throw error;
  }
}

async function updateConversation(from, to, data) {
  const syncService = context.getTwilioClient().sync.v1.services(context.SYNC_SERVICE_SID);
  const docName = `conv-${from}-${to}`;

  try {
    await syncService.documents(docName).update({ data });
  } catch (error) {
    if (error.status === 404) {
      await syncService.documents.create({ uniqueName: docName, data });
    } else {
      throw error;
    }
  }
}
```

### Two-Way SMS Survey

```javascript
exports.handler = async function(context, event, callback) {
  const twiml = new Twilio.twiml.MessagingResponse();
  const from = event.From;
  const body = (event.Body || '').toLowerCase().trim();

  // Get current survey state
  const state = await getConversation(from, event.To);

  switch (state.step || 'start') {
    case 'start':
      twiml.message('Welcome to our survey! On a scale of 1-10, how satisfied are you?');
      state.step = 'rating';
      break;

    case 'rating':
      const rating = parseInt(body, 10);
      if (rating >= 1 && rating <= 10) {
        state.rating = rating;
        twiml.message('Thanks! Any additional comments? Reply SKIP to finish.');
        state.step = 'comments';
      } else {
        twiml.message('Please enter a number between 1 and 10.');
      }
      break;

    case 'comments':
      state.comments = body === 'skip' ? null : body;
      twiml.message('Thank you for your feedback!');
      state.step = 'complete';
      // Save survey results
      break;

    case 'complete':
      twiml.message('Survey already completed. Thank you!');
      break;
  }

  await updateConversation(from, event.To, state);
  callback(null, twiml);
};
```

---

## International Messaging

### Sender ID Requirements by Country

| Country | Long Code | Short Code | Alphanumeric |
|---------|-----------|------------|--------------|
| USA | Yes | Yes | No |
| Canada | Yes | Yes | Yes |
| UK | Yes | Yes | Yes |
| Australia | Yes | Yes | Yes |
| Germany | No | Yes | Yes |
| India | No | Yes | Required |

### Geographic Sender Selection

```javascript
// Messaging Services automatically select best sender
const message = await client.messages.create({
  to: '+447911123456',  // UK number
  messagingServiceSid: context.TWILIO_MESSAGING_SERVICE_SID,
  body: 'Hello from the UK!'
  // Service will use UK number if available
});
```

---

## File Naming Conventions

| Suffix | Access Level | Use Case |
|--------|--------------|----------|
| `.js` | Public | General endpoints, health checks |
| `.protected.js` | Twilio Only | Webhooks (validates signature) |
| `.private.js` | Internal | Helper functions, not HTTP accessible |

---

## Testing Messaging Functions

### Unit Test TwiML Generation

```javascript
describe('incoming-sms', () => {
  it('responds to HELP keyword', async () => {
    const event = { From: '+14155551234', To: '+14155559876', Body: 'HELP' };

    const result = await new Promise((resolve) => {
      handler(context, event, (err, response) => {
        resolve(response.toString());
      });
    });

    expect(result).toContain('<Message>');
    expect(result).toContain('Commands:');
  });

  it('handles empty body gracefully', async () => {
    const event = { From: '+14155551234', To: '+14155559876', Body: '' };

    const result = await new Promise((resolve) => {
      handler(context, event, (err, response) => {
        resolve(response.toString());
      });
    });

    expect(result).toContain('<Message>');
  });
});
```

### Integration Test (Send Real SMS)

```javascript
const client = require('twilio')(accountSid, authToken);

const message = await client.messages.create({
  to: testPhoneNumber,
  from: twilioPhoneNumber,
  body: 'Integration test message',
  statusCallback: `${baseUrl}/test-status`
});

expect(message.sid).toMatch(/^SM/);
expect(message.status).toBe('queued');
```
