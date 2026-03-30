---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: SendGrid Event Webhook reference covering all event types, payload fields, and webhook security. -->
<!-- ABOUTME: Read when implementing event webhook handlers or debugging delivery issues. -->

# SendGrid Event Webhook Reference

## Overview

The Event Webhook sends HTTP POST requests to your URL when email events occur. Events are batched — each POST contains a JSON array of one or more event objects.

Configure in SendGrid Console: Settings > Mail Settings > Event Webhook.

---

## Event Types

### Delivery Events

| Event | Trigger | Key Fields |
|-------|---------|------------|
| `processed` | Message accepted by SendGrid for delivery | `sg_message_id`, `email` |
| `deferred` | Receiving server temporarily rejected (will retry) | `email`, `response`, `attempt` |
| `delivered` | Receiving server accepted the message | `email`, `response`, `sg_message_id` |
| `bounce` | Receiving server permanently rejected | `email`, `type` (`bounce`/`blocked`), `reason`, `status` |
| `dropped` | SendGrid will not deliver (suppression, invalid, etc.) | `email`, `reason` |

### Engagement Events

| Event | Trigger | Key Fields |
|-------|---------|------------|
| `open` | Recipient opened email (tracking pixel loaded) | `email`, `useragent`, `ip` |
| `click` | Recipient clicked a tracked link | `email`, `url`, `useragent`, `ip` |
| `spamreport` | Recipient marked as spam via ISP feedback loop | `email` |
| `unsubscribe` | Recipient clicked SendGrid unsubscribe link | `email` |
| `group_unsubscribe` | Recipient unsubscribed from ASM group | `email`, `asm_group_id` |
| `group_resubscribe` | Recipient resubscribed to ASM group | `email`, `asm_group_id` |

---

## Common Payload Fields

Every event object includes these fields:

| Field | Type | Description |
|-------|------|-------------|
| `email` | string | Recipient email address |
| `timestamp` | integer | Unix timestamp of the event |
| `event` | string | Event type (see tables above) |
| `sg_event_id` | string | Unique event ID |
| `sg_message_id` | string | SendGrid internal message ID (matches `X-Message-Id` header) |
| `category` | array | Categories assigned to the message |
| `unique_args` | object | Custom args (`custom_args`) from the send request — renamed to `unique_args` in webhook payload |

### Bounce-Specific Fields

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | `bounce` (hard) or `blocked` (soft/policy) |
| `reason` | string | SMTP response from receiving server |
| `status` | string | SMTP status code (e.g., `5.1.1`) |

### Click-Specific Fields

| Field | Type | Description |
|-------|------|-------------|
| `url` | string | The URL that was clicked |
| `url_offset` | object | `{ index: N, type: "html" }` — position of link in content |

### Open-Specific Fields

| Field | Type | Description |
|-------|------|-------------|
| `useragent` | string | Recipient's email client user agent |
| `ip` | string | IP address of the opener |

---

## Webhook Security

### Signed Event Webhook (Recommended)

SendGrid supports ECDSA (P-256, SHA-256) signature verification. Enable in Console under Mail Settings > Signed Event Webhook.

When enabled, each POST includes:

| Header | Description |
|--------|-------------|
| `X-Twilio-Email-Event-Webhook-Signature` | ECDSA signature (base64) |
| `X-Twilio-Email-Event-Webhook-Timestamp` | Unix timestamp used in signature |

Verification steps:
1. Concatenate timestamp + raw POST body
2. Verify ECDSA signature using the public key from the Signed Event Webhook settings
3. Reject if signature invalid or timestamp too old (>5 minutes = replay attack)

```javascript
const { EventWebhook, EventWebhookHeader } = require('@sendgrid/eventwebhook');

function verifyWebhook(publicKey, payload, signature, timestamp) {
  const ew = new EventWebhook();
  const ecPublicKey = ew.convertPublicKeyToECDSA(publicKey);
  return ew.verifySignature(ecPublicKey, payload, signature, timestamp);
}
```

### Without Signed Webhook

If not using signed webhooks, consider:
- **Basic auth in the URL** — `https://user:pass@your-domain.com/webhook` (SendGrid supports this)
- **Secret query parameter** — `https://your-domain.com/webhook?token=secret`
- **IP allowlisting** — SendGrid publishes their sending IP ranges

---

## Event Ordering

Events are **not guaranteed to arrive in chronological order**. A `delivered` event may arrive before the `processed` event. Design your handler to be idempotent and order-independent.

Events may also be **duplicated** during retries. Use `sg_event_id` for deduplication.

---

## Retry Behavior

If your webhook endpoint returns a non-2xx response:

- SendGrid retries with exponential backoff
- Retries continue for up to 24 hours
- After 24 hours of failures, the webhook is disabled
- You must manually re-enable it in the Console

Return `2xx` as quickly as possible. Process events asynchronously if your logic is slow.

---

## Batching

- Events are batched into single POST requests
- Batch sizes vary (typically 1-1,000 events per POST)
- No configuration for batch size or frequency
- Your endpoint must handle arrays, not single objects

```javascript
// Correct: handle array
app.post('/webhook', (req, res) => {
  const events = req.body; // Array of event objects
  events.forEach(event => processEvent(event));
  res.sendStatus(200);
});
```

---

## Event Filtering

You can select which event types to receive in the Console. Common configurations:

| Use Case | Events to Enable |
|----------|-----------------|
| Deliverability monitoring | `bounce`, `dropped`, `deferred`, `delivered` |
| Engagement tracking | `open`, `click` |
| Compliance | `spamreport`, `unsubscribe`, `group_unsubscribe` |
| Full observability | All events |

Disable events you don't process to reduce webhook volume.
