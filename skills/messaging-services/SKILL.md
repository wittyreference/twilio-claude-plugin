---
name: messaging-services
description: Twilio Messaging Services for sender pools, A2P 10DLC compliance, and geographic routing. Use for high-volume messaging or multiple sender numbers.
---

# Messaging Services Skill

Knowledge for building Twilio Messaging Services functions for advanced SMS/MMS capabilities with sender pools, intelligent routing, and compliance features.

## What are Messaging Services?

Messaging Services provide enterprise-grade messaging features beyond basic SMS:
- **Sender Pool**: Multiple phone numbers for scale and deliverability
- **Sticky Sender**: Same number for ongoing conversations with a recipient
- **Geographic Matching**: Use local numbers when available
- **MMS Conversion**: Auto-fallback when MMS isn't supported
- **Link Shortening**: Track click-through rates
- **Compliance**: Built-in opt-out management
- **A2P 10DLC**: Application-to-Person messaging compliance (US)

## Key Difference: `from` vs `messagingServiceSid`

```javascript
// Basic SMS - specify sender number
await client.messages.create({
  to: '+1234567890',
  from: '+0987654321',  // Specific phone number
  body: 'Hello!'
});

// Messaging Service - let Twilio pick optimal sender
await client.messages.create({
  to: '+1234567890',
  messagingServiceSid: context.TWILIO_MESSAGING_SERVICE_SID,  // Service selects number
  body: 'Hello!'
});
```

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

## A2P 10DLC Compliance (US)

For US messaging, register your brand and campaigns:

### Campaign Use Cases

| Use Case | Description | Throughput |
|----------|-------------|------------|
| `marketing` | Promotional messages | Standard |
| `notifications` | Transactional alerts | Higher |
| `customer_care` | Support conversations | Higher |
| `delivery_notifications` | Shipping updates | Higher |
| `account_notification` | Account alerts | Higher |
| `2fa` | Two-factor authentication | Highest |

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
