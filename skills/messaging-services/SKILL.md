---
name: messaging-services
description: Twilio Messaging Services for sender pools, A2P 10DLC compliance, and geographic routing. Use for high-volume messaging or multiple sender numbers.
---

# Messaging Services Skill

Knowledge for building Twilio Messaging Services functions for advanced SMS/MMS capabilities with sender pools, intelligent routing, and compliance features.

## Key Difference from Basic Messaging

Uses `messagingServiceSid` instead of `from` — Twilio selects the optimal sender from the pool:

```javascript
// Basic: await client.messages.create({ to, from: phoneNumber, body });
// Service: await client.messages.create({ to, messagingServiceSid: serviceSid, body });
```

## Service Features (Overview)

- **Sender Pool**: Multiple numbers for scale and deliverability
- **Sticky Sender**: Same number for ongoing conversations
- **Geographic Matching**: Local numbers when available
- **MMS Conversion**: Auto-fallback when MMS unsupported
- **Smart Encoding**: GSM-compatible character conversion
- **Link Shortening**: Click-through tracking
- **Compliance**: Built-in opt-out (STOP/HELP) management

## A2P 10DLC (US)

Registration flow: Brand > Campaign > Number Assignment. Required for US messaging at scale.

| Use Case | Throughput |
|----------|-----------|
| `2fa` | Highest |
| `notifications`, `customer_care`, `delivery_notifications`, `account_notification` | Higher |
| `marketing` | Standard |

### Registration Timeline

**Total: 2-10+ business days.** Do NOT promise same-day high-volume messaging.

| Stage | Duration | Notes |
|-------|----------|-------|
| Brand registration | 1-7 business days | Vetting by TCR. Sole proprietors take longer |
| Campaign registration | 1-3 business days | Per-campaign review |
| Number assignment | Instant | After campaign approval |
| Throughput ramp | 1-14 days | Starts at low TPS, ramps to campaign limit |

For 50K+ messages/day, budget 2-4 weeks total including ramp-up. Unregistered traffic on 10DLC numbers gets filtered aggressively.

## API Overview

### Sending Messages via Messaging Service

```javascript
const client = context.getTwilioClient();

// Basic send
const message = await client.messages.create({
  to: '+1234567890',
  messagingServiceSid: context.TWILIO_MESSAGING_SERVICE_SID,
  body: 'Your order has shipped!'
});

// With media (MMS)
const message = await client.messages.create({
  to: '+1234567890',
  messagingServiceSid: context.TWILIO_MESSAGING_SERVICE_SID,
  body: 'Check out this image!',
  mediaUrl: ['https://example.com/image.jpg']
});

// With status callback
const message = await client.messages.create({
  to: '+1234567890',
  messagingServiceSid: context.TWILIO_MESSAGING_SERVICE_SID,
  body: 'Tracking delivery...',
  statusCallback: 'https://your-app.com/status'
});

// Schedule message (up to 7 days in advance)
const message = await client.messages.create({
  to: '+1234567890',
  messagingServiceSid: context.TWILIO_MESSAGING_SERVICE_SID,
  body: 'Scheduled reminder!',
  scheduleType: 'fixed',
  sendAt: new Date(Date.now() + 3600000).toISOString()  // 1 hour from now
});
```

### Managing Sender Pool

```javascript
// List phone numbers in the service
const phoneNumbers = await client.messaging.v1
  .services(context.TWILIO_MESSAGING_SERVICE_SID)
  .phoneNumbers.list();

// Add phone number to service
await client.messaging.v1
  .services(context.TWILIO_MESSAGING_SERVICE_SID)
  .phoneNumbers.create({
    phoneNumberSid: 'PNxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
  });

// Remove phone number from service
await client.messaging.v1
  .services(context.TWILIO_MESSAGING_SERVICE_SID)
  .phoneNumbers(phoneNumberSid).remove();
```

### Service Configuration

```javascript
// Get service details
const service = await client.messaging.v1
  .services(context.TWILIO_MESSAGING_SERVICE_SID).fetch();

// Update service settings
await client.messaging.v1
  .services(context.TWILIO_MESSAGING_SERVICE_SID).update({
    stickySender: true,
    mmsConverter: true,
    smartEncoding: true,
    fallbackUrl: 'https://fallback.example.com/sms',
    inboundRequestUrl: 'https://your-app.com/incoming',
    statusCallback: 'https://your-app.com/status'
  });
```

## Service Features

### Sticky Sender

Maintains consistent sender number per recipient:

```javascript
// Service config
{
  "stickySender": true
}

// First message to +1234567890 goes from +1111111111
// All future messages to +1234567890 come from +1111111111
```

### Geographic Matching

Selects sender number closest to recipient:

```javascript
// Service config
{
  "usecase": "marketing",  // or "notifications", "verification", etc.
  "areaCodeGeomatch": true
}

// Message to +1415... will prefer +1415... sender if available
```

### MMS Conversion

Auto-converts MMS to SMS with link for unsupported carriers:

```javascript
// Service config
{
  "mmsConverter": true
}

// MMS to carrier without MMS support becomes:
// "Check out this image! https://twil.io/abc123"
```

### Smart Encoding

Automatically uses optimal character encoding:

```javascript
// Service config
{
  "smartEncoding": true
}

// Converts special characters to GSM-compatible equivalents
// Reduces message segments and cost
```

### Link Shortening

Track link clicks with branded short links:

```javascript
// Enable on service
{
  "useInboundWebhookOnNumber": false,
  "validityPeriod": 14400
}

// Send with link shortening
const message = await client.messages.create({
  to: '+1234567890',
  messagingServiceSid: context.TWILIO_MESSAGING_SERVICE_SID,
  body: 'Check out our sale: https://example.com/big-sale-promo-2024',
  shortenUrls: true
});

// Results in: "Check out our sale: https://twil.io/abc123"
```

## Webhook Parameters

### Inbound Message Webhook

Same as standard messaging, plus:

| Parameter | Description |
|-----------|-------------|
| `MessagingServiceSid` | The Messaging Service that received the message |
| All standard SMS params | `From`, `To`, `Body`, `MessageSid`, etc. |

### Status Callback

| Parameter | Description |
|-----------|-------------|
| `MessageSid` | Message identifier |
| `MessageStatus` | `queued`, `sent`, `delivered`, `undelivered`, `failed` |
| `ErrorCode` | Error code if failed |
| `ErrorMessage` | Error description if failed |
| `MessagingServiceSid` | Associated Messaging Service |

## Common Patterns

### High-Volume Notifications

```javascript
exports.handler = async (context, event, callback) => {
  const client = context.getTwilioClient();
  const { recipients, message } = event;

  const results = await Promise.allSettled(
    recipients.map(recipient =>
      client.messages.create({
        to: recipient,
        messagingServiceSid: context.TWILIO_MESSAGING_SERVICE_SID,
        body: message
      })
    )
  );

  const sent = results.filter(r => r.status === 'fulfilled').length;
  const failed = results.filter(r => r.status === 'rejected').length;

  return callback(null, { sent, failed, total: recipients.length });
};
```

### Opt-Out Handling

Messaging Services automatically handle STOP/HELP keywords:

```javascript
exports.handler = async (context, event, callback) => {
  const twiml = new Twilio.twiml.MessagingResponse();

  // Twilio auto-handles STOP, STOPALL, UNSUBSCRIBE, CANCEL, END, QUIT
  // These never reach your webhook

  // Handle HELP
  if (event.Body.toUpperCase() === 'HELP') {
    twiml.message('Reply STOP to unsubscribe. For support: support@example.com');
    return callback(null, twiml);
  }

  // Normal message handling
  twiml.message('Thanks for your message!');
  return callback(null, twiml);
};
```

### Status Tracking

```javascript
exports.handler = async (context, event, callback) => {
  const { MessageSid, MessageStatus, ErrorCode, ErrorMessage } = event;

  // Log status update
  console.log(`Message ${MessageSid}: ${MessageStatus}`);

  if (MessageStatus === 'failed' || MessageStatus === 'undelivered') {
    console.log(`Delivery failed: ${ErrorCode} - ${ErrorMessage}`);
    // Handle failure (retry, alert, etc.)
  }

  if (MessageStatus === 'delivered') {
    // Update delivery tracking in your system
  }

  return callback(null, { success: true });
};
```

### Scheduled Campaigns

```javascript
exports.handler = async (context, event, callback) => {
  const client = context.getTwilioClient();
  const { recipients, message, sendAt } = event;

  // Validate sendAt is within 7 days
  const scheduledTime = new Date(sendAt);
  const maxTime = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

  if (scheduledTime > maxTime) {
    return callback(null, {
      success: false,
      error: 'Messages can only be scheduled up to 7 days in advance'
    });
  }

  const results = await Promise.allSettled(
    recipients.map(recipient =>
      client.messages.create({
        to: recipient,
        messagingServiceSid: context.TWILIO_MESSAGING_SERVICE_SID,
        body: message,
        scheduleType: 'fixed',
        sendAt: scheduledTime.toISOString()
      })
    )
  );

  return callback(null, {
    scheduled: results.filter(r => r.status === 'fulfilled').length,
    failed: results.filter(r => r.status === 'rejected').length
  });
};
```

## Error Handling

### Common Error Codes

| Code | Description |
|------|-------------|
| `21211` | Invalid 'To' phone number |
| `21408` | Permission to send not enabled |
| `21610` | Attempt to send to unsubscribed recipient |
| `21611` | Messaging Service has no phone numbers |
| `21614` | 'To' number not verified (trial accounts) |
| `21617` | Messaging Service not found |
| `30003` | Unreachable destination |
| `30004` | Message blocked (spam) |
| `30005` | Unknown destination number |
| `30006` | Landline or unreachable carrier |
| `30007` | Carrier violation |
| `30008` | Unknown error |

### Error Handling Pattern

```javascript
exports.handler = async (context, event, callback) => {
  const client = context.getTwilioClient();

  try {
    const message = await client.messages.create({
      to: event.to,
      messagingServiceSid: context.TWILIO_MESSAGING_SERVICE_SID,
      body: event.body
    });

    return callback(null, { success: true, sid: message.sid });
  } catch (error) {
    if (error.code === 21610) {
      return callback(null, {
        success: false,
        error: 'Recipient has opted out of messages'
      });
    }
    if (error.code === 21611) {
      return callback(null, {
        success: false,
        error: 'No phone numbers in Messaging Service. Add numbers to sender pool.'
      });
    }
    if (error.code === 30004) {
      return callback(null, {
        success: false,
        error: 'Message blocked by carrier. Review message content.'
      });
    }
    throw error;
  }
};
```

## Testing Messaging Services

### Test Numbers

Use Twilio test credentials for development. See Twilio docs for current magic test numbers that simulate success and failure scenarios.

### Integration Test

```javascript
describe('Messaging Service', () => {
  it('should send message via messaging service', async () => {
    const context = createTestContext();
    const event = {
      to: testPhoneNumber,
      body: 'Test message'
    };

    await sendHandler(context, event, callback);

    const [, response] = callback.mock.calls[0];
    expect(response.success).toBe(true);
    expect(response.sid).toMatch(/^SM/);
  });

  it('should handle opt-out error', async () => {
    const context = createTestContext();
    const event = { to: '+1234567890', body: 'Test' };

    await sendHandler(context, event, callback);

    const [, response] = callback.mock.calls[0];
    expect(response.success).toBe(false);
    expect(response.error).toContain('opted out');
  });
});
```

## Environment Variables

```
TWILIO_MESSAGING_SERVICE_SID=MGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Create a Messaging Service in the Twilio Console:
1. Go to Messaging > Services
2. Create new service
3. Configure features (sticky sender, geographic matching, etc.)
4. Add phone numbers to sender pool
5. Set up webhooks for inbound and status callbacks

## Best Practices

1. **Use Sender Pools**: Add multiple numbers for scale and deliverability
2. **Enable Sticky Sender**: Maintain consistent sender for conversations
3. **Configure Fallbacks**: Set fallback URLs for resilience
4. **Monitor Delivery**: Use status callbacks to track delivery rates
5. **Handle Opt-Outs Gracefully**: Never send to opted-out recipients
6. **Register for A2P 10DLC**: Required for US messaging at scale
7. **Use Appropriate Use Cases**: Match campaign registration to actual use
8. **Set Up Link Shortening**: Track engagement for marketing messages

## Gotchas

- **Empty Sender Pool**: Error 21611 if no numbers added to service. Add numbers before sending.
- **Sticky Sender Persistence**: Binding persists even after removing a number. Clear via API if needed.
- **10DLC Registration Required**: US A2P messaging without registration gets heavily filtered.
- **Scheduled Message Limits**: Max 7 days in advance. `scheduleType: 'fixed'` required.
- **MMS Conversion Side Effects**: With `mmsConverter: true`, MMS becomes SMS+link on some carriers — changes UX.
- **Opt-Out Auto-Handling**: STOP/STOPALL/etc. never reach your webhook. Don't try to intercept them.
