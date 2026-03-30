---
name: "sendgrid-email"
description: "Twilio development skill: sendgrid-email"
---

---
name: sendgrid-email
description: >
  SendGrid Email API development guide. Use when sending transactional or marketing email,
  building email templates, configuring webhooks for delivery events, processing inbound email
  via Inbound Parse, managing suppressions, or choosing between SendGrid and Twilio messaging
  for email delivery.
---

<!-- ABOUTME: SendGrid Email API skill covering v3 Mail Send, templates, webhooks, Inbound Parse, and suppressions. -->
<!-- ABOUTME: Loaded when building email features in Twilio Serverless Functions or standalone Node.js apps. -->

# SendGrid Email

Guide for building email features with the SendGrid v3 API via the `@sendgrid/mail` Node.js SDK (`v8.x`). Covers transactional sends, dynamic templates, event webhooks, Inbound Parse, suppression management, and domain authentication.

**Scope**: This skill covers the **Email API** (transactional and bulk sending). It does not cover Marketing Campaigns UI, Ads, or the legacy v2 API.

**No MCP tools exist for SendGrid** — all operations use the `@sendgrid/mail` SDK or direct REST API calls with `@sendgrid/client`. No CLI equivalent exists for SendGrid operations.

---

## Scope

### CAN

- Send transactional email (single recipient or batch up to 1,000 recipients per request)
- Send bulk email using personalizations (up to 1,000 personalizations per request, each with its own `to`/`cc`/`bcc`, subject, headers, substitutions, dynamic template data, `send_at`, and custom args)
- Use dynamic templates with Handlebars syntax (conditionals, iteration, custom helpers)
- Attach files up to 30MB total per request (base64-encoded in the JSON payload)
- Schedule sends up to 72 hours in advance via `send_at` (Unix timestamp)
- Cancel scheduled sends using batch IDs (must assign batch ID before sending)
- Receive delivery event webhooks (processed, delivered, deferred, bounce, dropped, open, click, spam report, unsubscribe, group unsubscribe, group resubscribe)
- Receive inbound email via Inbound Parse webhook (parsed or raw mode)
- Manage suppressions programmatically (bounces, blocks, spam reports, unsubscribes, invalid emails)
- Validate email addresses via the Email Validation API (syntax, DNS, mailbox checks)
- Send AMP for Email content alongside HTML/plain text fallbacks
- Use sandbox mode for testing without delivering email
- Track opens and clicks with configurable tracking settings per message
- Set IP pools for sending reputation isolation
- Use suppression groups (ASM) for category-based unsubscribe management

### CANNOT

- **Send more than 1,000 recipients per API call** — split into multiple requests. This is a hard API limit, not configurable.
- **Schedule sends more than 72 hours in advance** — the `send_at` parameter rejects timestamps beyond 72h from now.
- **Cancel a send after it has been processed** — only scheduled (not-yet-sent) messages with a batch ID can be cancelled.
- **Receive real-time delivery confirmation synchronously** — the Mail Send API returns `202 Accepted` (queued), not `200 OK` (delivered). Delivery status comes asynchronously via Event Webhook.
- **Use Handlebars template logic in the subject line from personalizations** — `dynamic_template_data` works in the template body, but the `subject` field in personalizations is a plain string, not a template.
- **Guarantee open tracking accuracy** — open tracking uses a pixel image; email clients that block images produce false negatives, and prefetch/privacy features produce false positives.
- **Send from an unauthenticated domain in production** — domain authentication (DKIM/SPF via CNAME records) is required. Single Sender Verification is only for testing.
- **Access SendGrid features via Twilio MCP tools** — SendGrid has a separate API with its own authentication (API keys, not Account SID/Auth Token). No MCP tools wrap SendGrid.
- **Use Twilio Serverless environment variables for SendGrid auth** — you must add `SENDGRID_API_KEY` to your `.env` file manually; it is not part of the Twilio credential chain.
- **Exceed 30MB total attachment size per request** — attachments are base64-encoded in the JSON body, so the raw file limit is effectively ~22MB before encoding overhead.

---

## Quick Decision

| Need | Use | Why |
|------|-----|-----|
| Send transactional email from a serverless function | `@sendgrid/mail` SDK in a Twilio Function | Direct API call, no SMTP overhead, returns in ~200ms |
| Send to >1,000 recipients | Multiple API calls with 1,000 per batch | API hard limit per request |
| Personalize per-recipient (name, data) | `personalizations` array with `dynamic_template_data` | Each personalization gets its own merge data |
| Know if email was delivered | Event Webhook → `delivered` event | Mail Send only returns `202 Accepted` (queued) |
| Receive email at your domain | Inbound Parse webhook | Converts inbound email to HTTP POST to your endpoint |
| Test without sending real email | `mail_settings.sandbox_mode.enable: true` | Returns `200 OK` with validation but no delivery |
| Brand your sending domain | Domain Authentication in SendGrid Console | Sets DKIM/SPF via CNAME records on your DNS |
| Cancel a scheduled email | Create batch ID first, then `PATCH /mail/batch/{id}` | Batch ID must be assigned before the send, not after |
| Verify an email address is real | Email Validation API (`POST /validations/email`) | Checks syntax + DNS + mailbox (paid add-on) |

---

## Decision Frameworks

### Sending Method

| Scenario | Method | Details |
|----------|--------|---------|
| Single recipient, simple content | `sgMail.send(msg)` | Minimal payload, one personalization auto-created |
| Multiple recipients, same content | Single `to` array or multiple personalizations | `to` array = all see each other; personalizations = isolated |
| Per-recipient customization | `personalizations` with `dynamic_template_data` | Each recipient gets unique merge variables |
| High-volume batch (>1,000) | Multiple API calls, 1,000/call | Use `sgMail.sendMultiple()` for convenience splitting |
| Scheduled future send | `send_at` (Unix timestamp) + `batch_id` | Batch ID required if you want cancel capability |
| Template-driven content | Dynamic templates + `template_id` | Design in SendGrid UI, pass data via `dynamic_template_data` |
| Raw HTML/text without templates | `content` array with `type` + `value` | `text/plain` and `text/html` in the content array |

### Authentication for Sending

| Stage | Method | Notes |
|-------|--------|-------|
| Development/testing | Single Sender Verification | Verify one email address in SendGrid Console. Quick but limited. |
| Production | Domain Authentication | CNAME records for DKIM + SPF. Required for deliverability. |
| High-volume production | Domain Auth + Dedicated IP | Isolate sending reputation. Available on Pro+ plans. |

### Content Type Priority

When sending multiple content types, SendGrid uses this display priority (highest to lowest):

1. `text/x-amp-html` (AMP for Email — only in supporting clients)
2. `text/html` (standard HTML — most email clients)
3. `text/plain` (plaintext fallback)

Include at least `text/plain` and `text/html`. AMP is optional and requires sender registration with email providers.

---

## Integration Patterns

### Basic Send from Twilio Serverless Function

```javascript
// send.protected.js
const sgMail = require('@sendgrid/mail');

exports.handler = async function (context, event, callback) {
  sgMail.setApiKey(context.SENDGRID_API_KEY);

  const msg = {
    to: event.to,
    from: context.SENDGRID_FROM_EMAIL, // Must be verified sender or authenticated domain
    subject: event.subject,
    text: event.textBody,
    html: event.htmlBody,
  };

  try {
    const [response] = await sgMail.send(msg);
    // response.statusCode === 202 means queued, NOT delivered
    callback(null, { success: true, statusCode: response.statusCode });
  } catch (error) {
    const errorBody = error.response ? error.response.body : error.message;
    callback(errorBody);
  }
};
```

### Personalized Batch Send with Dynamic Template

```javascript
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

const msg = {
  from: { email: 'noreply@example.com', name: 'My App' },
  template_id: 'd-xxxxxxxxxxxxxxxxxxxxxxxxxxxx', // Dynamic template ID from SendGrid UI
  personalizations: [
    {
      to: [{ email: 'alice@example.com', name: 'Alice' }],
      dynamic_template_data: {
        first_name: 'Alice',
        order_id: '12345',
        items: [
          { name: 'Widget', qty: 2, price: '$9.99' },
          { name: 'Gadget', qty: 1, price: '$24.99' },
        ],
      },
    },
    {
      to: [{ email: 'bob@example.com', name: 'Bob' }],
      dynamic_template_data: {
        first_name: 'Bob',
        order_id: '12346',
        items: [{ name: 'Gizmo', qty: 3, price: '$14.99' }],
      },
    },
  ],
};

const [response] = await sgMail.send(msg);
```

### Scheduled Send with Cancel Capability

```javascript
const client = require('@sendgrid/client');
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(process.env.SENDGRID_API_KEY);
client.setApiKey(process.env.SENDGRID_API_KEY);

// Step 1: Generate a batch ID
const [batchResponse] = await client.request({
  method: 'POST',
  url: '/v3/mail/batch',
});
const batchId = batchResponse.body.batch_id;

// Step 2: Send with batch_id and send_at
const sendAt = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
const msg = {
  to: 'recipient@example.com',
  from: 'sender@example.com',
  subject: 'Scheduled email',
  text: 'This will arrive in 1 hour.',
  send_at: sendAt,
  batch_id: batchId,
};
await sgMail.send(msg);

// Step 3: Cancel before it sends (if needed)
await client.request({
  method: 'POST',
  url: '/v3/user/scheduled_sends',
  body: { batch_id: batchId, status: 'cancel' },
});
```

### Send with Attachments

```javascript
const fs = require('fs');
const path = require('path');

const attachment = fs.readFileSync(path.join(__dirname, 'invoice.pdf'));

const msg = {
  to: 'recipient@example.com',
  from: 'billing@example.com',
  subject: 'Your Invoice',
  html: '<p>Please find your invoice attached.</p>',
  attachments: [
    {
      content: attachment.toString('base64'),
      filename: 'invoice.pdf',
      type: 'application/pdf',
      disposition: 'attachment', // or 'inline' for embedded images
      content_id: 'invoice',    // Required for inline disposition
    },
  ],
};
```

### Event Webhook Handler (Twilio Function)

```javascript
// webhook.js (public — SendGrid cannot sign like Twilio)
exports.handler = function (context, event, callback) {
  // SendGrid posts an array of event objects
  const events = Array.isArray(event) ? event : [event];

  for (const evt of events) {
    switch (evt.event) {
      case 'delivered':
        console.log(`Delivered to ${evt.email} (sg_message_id: ${evt.sg_message_id})`);
        break;
      case 'bounce':
        console.log(`Bounce: ${evt.email}, type: ${evt.type}, reason: ${evt.reason}`);
        break;
      case 'dropped':
        console.log(`Dropped: ${evt.email}, reason: ${evt.reason}`);
        break;
      case 'open':
        console.log(`Opened by ${evt.email}, useragent: ${evt.useragent}`);
        break;
      case 'click':
        console.log(`Click by ${evt.email}, url: ${evt.url}`);
        break;
      case 'spamreport':
        console.log(`Spam report from ${evt.email}`);
        break;
    }
  }

  callback(null, ''); // Return 2xx to acknowledge
};
```

### Inbound Parse Handler

```javascript
// inbound.js (public endpoint for SendGrid Inbound Parse)
exports.handler = function (context, event, callback) {
  // Parsed mode fields (default)
  const from = event.from;           // "Name <email@example.com>"
  const to = event.to;              // Envelope to
  const subject = event.subject;
  const text = event.text;          // Plain text body
  const html = event.html;          // HTML body
  const envelope = JSON.parse(event.envelope); // { to: [...], from: "..." }
  const attachmentCount = parseInt(event.attachments || '0', 10);

  console.log(`Inbound email from ${from}: ${subject}`);
  console.log(`Attachments: ${attachmentCount}`);

  // Process the email...
  callback(null, '');
};
```

---

## Gotchas

### Authentication & Setup

1. **API key scope matters**: A "Mail Send" restricted key can send email but cannot read suppressions, manage templates, or access stats. Use "Full Access" during development, then scope down for production. If you get `403 Forbidden`, check key permissions first.

2. **`SENDGRID_API_KEY` is not a Twilio credential**: It lives in the SendGrid Console under Settings > API Keys. It starts with `SG.` — if your key doesn't start with `SG.`, it's not a SendGrid API key.

3. **Single Sender Verification expires**: Verified single senders must re-verify if the associated email address changes. For production, use Domain Authentication instead.

4. **Domain Authentication requires DNS access**: You need to create 3 CNAME records (2 for DKIM, 1 for return path) plus optionally a link branding CNAME. If you cannot modify DNS, you cannot authenticate a domain.

### Sending

5. **`202 Accepted` does not mean delivered**: The Mail Send endpoint returns `202` when the message is queued for processing. Delivery status arrives asynchronously via Event Webhook. A `202` response with a `2xx` does not guarantee the email will reach the inbox.

6. **Empty `content` when using `template_id`**: When using a dynamic template, omit the `content` field entirely. If you include both `template_id` and `content`, the template content takes precedence and the `content` array is ignored.

7. **Personalizations `to` visibility**: Recipients in the same `to` array within a single personalization can see each other's addresses. To hide recipients from each other, use separate personalizations (one per recipient).

8. **`send_at` is Unix seconds, not milliseconds**: JavaScript `Date.now()` returns milliseconds. Divide by 1000: `Math.floor(Date.now() / 1000) + delay`. Using milliseconds silently produces a date far in the future and the API rejects it (>72h limit).

9. **`reply_to` is message-level only**: You can set a different `reply_to` per message, but not per personalization. All recipients in one API call share the same reply-to address.

10. **Attachment `content` must be base64**: The SDK does not auto-encode files. You must call `.toString('base64')` on the buffer yourself. Sending raw binary in the `content` field produces a `400 Bad Request`.

### Templates & Handlebars

11. **Template version matters**: Dynamic templates (IDs starting with `d-`) support Handlebars. Legacy transactional templates use `-` substitution syntax (`-name-`). The two are not interchangeable.

12. **Handlebars helpers are limited**: SendGrid supports `if`, `unless`, `each`, `equals`, `notEquals`, `and`, `or`, `greaterThan`, `lessThan`, `length`, `formatDate`, `insert`. It does not support custom helpers, inline partials, or the full Handlebars.js spec.

13. **Undefined template variables render as empty string**: Unlike Handlebars.js which renders `undefined`, SendGrid renders missing `dynamic_template_data` keys as empty strings with no error. This makes typos in variable names silent failures.

### Webhooks & Events

14. **Event Webhook posts batched arrays**: SendGrid batches multiple events into a single POST. Your handler receives a JSON array, not a single event object. Failing to handle the array format drops events silently.

15. **Event Webhook has no built-in signature verification**: Unlike Twilio webhooks, SendGrid Event Webhooks do not include a request signature by default. You can enable Signed Event Webhook (ECDSA P-256) in the SendGrid Console under Mail Settings, but it is not on by default.

16. **Open tracking is unreliable by design**: Apple Mail Privacy Protection, Outlook privacy settings, and corporate proxies pre-fetch tracking pixels, inflating open rates. Conversely, clients that block images produce zero opens. Do not use open events for business-critical logic.

17. **Inbound Parse requires MX record changes**: To receive email via Inbound Parse, you must point your domain's MX records to `mx.sendgrid.net`. This means you cannot use Inbound Parse on a domain that already receives email through another provider (e.g., Google Workspace) unless you use a subdomain.

### Rate Limits & Errors

18. **No per-endpoint rate limit headers on Mail Send**: Unlike most REST APIs, the v3 Mail Send endpoint does not return `X-RateLimit-*` headers. Rate limits are account-level and plan-dependent. When rate-limited, you receive `429 Too Many Requests`. Back off exponentially.

19. **Error response format varies**: Some endpoints return `{ errors: [{ message, field, help }] }` while others return `{ error: "string" }`. The SDK normalizes these into `error.response.body.errors` but direct REST callers should handle both shapes.

20. **`413 Payload Too Large` has no helpful message**: Exceeding the 30MB attachment limit returns `413` with no body. The error is not in the `errors` array format — it's just an empty response with the status code.

### Suppressions

21. **Suppressions are global by default**: If a recipient bounces or reports spam on any email from your account, they are suppressed from all future sends — not just from the category/group that triggered it. Use ASM suppression groups to scope unsubscribes to specific email types.

22. **Removing a suppression does not guarantee delivery**: Deleting a bounce record lets you attempt to send again, but the underlying deliverability issue (invalid mailbox, full inbox) likely persists. Re-sending to hard bounces damages your sender reputation.

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `SENDGRID_API_KEY` | Yes | API key from SendGrid Console (starts with `SG.`) |
| `SENDGRID_FROM_EMAIL` | Recommended | Default verified sender address |
| `SENDGRID_FROM_NAME` | Optional | Default sender display name |
| `SENDGRID_TEMPLATE_ID` | Optional | Default dynamic template ID (starts with `d-`) |

For Twilio Serverless Functions, add these to your `.env` file. The Twilio CLI deploys them as environment variables accessible via `context.SENDGRID_API_KEY`.

---

## Email Across Twilio

SendGrid is Twilio's email delivery engine. Other Twilio products reference email but do not send it themselves.

| Product | Role with Email | Sends email? | Skill |
|---------|----------------|--------------|-------|
| **SendGrid** (this skill) | Delivers transactional + bulk email, templates, webhooks, Inbound Parse | Yes | this file |
| **Conversations** (Conversations) | Tracks EMAIL as a channel type — participants, communications, capture rules | No — logs/tracks only | `/skills/conversations/SKILL.md` |
| **Verify** | Sends OTP codes via `channel: 'email'` | Delegates to SendGrid via Mailer config | `/skills/verify/SKILL.md` |
| **Voice AI** (unified stack) | EMAIL communications flow through Conversations into Memory + Intelligence pipelines | No — orchestrates only | `/skills/SKILL.md` |

**If you need to send email**: use this skill (SendGrid API).
**If you need to track email in omnichannel conversations**: use Conversations for tracking, SendGrid for delivery.
**If you need email OTP verification**: use Verify (which uses SendGrid under the hood — configure a Mailer on the Verify Service).

---

## Related Resources

| Resource | Path | When to use |
|----------|------|-------------|
| Verify skill | `/skills/verify/SKILL.md` | SendGrid is the email channel provider for Twilio Verify email OTPs |
| Conversations skill | `/skills/conversations/SKILL.md` | EMAIL channel tracking in omnichannel conversations |
| Voice AI skill | `/skills/SKILL.md` | Full Conversations + Memory + Intelligence pipeline with email |
| Twilio CLI guide | `/skills/twilio-cli/SKILL.md` | For deploying functions that use SendGrid |
| SendGrid Node.js SDK | npm `@sendgrid/mail` (v8.x) | Primary SDK for email operations |
| SendGrid Client SDK | npm `@sendgrid/client` (v8.x) | For non-mail endpoints (batch IDs, suppressions, templates) |

---

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| API reference | `references/api-reference.md` | Full endpoint list, request/response schemas, error codes |
| Event webhook reference | `references/event-webhook-reference.md` | Event types, payload fields, webhook security |
| Assertion audit | `references/assertion-audit.md` | Provenance chain for every factual claim in this skill |
