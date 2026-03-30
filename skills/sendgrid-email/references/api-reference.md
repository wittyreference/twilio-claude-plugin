---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: SendGrid v3 API endpoint reference covering Mail Send, templates, suppressions, and validation. -->
<!-- ABOUTME: Read when building against specific endpoints or debugging error responses. -->

# SendGrid v3 API Reference

## Authentication

All requests require an API key in the `Authorization` header:

```
Authorization: Bearer SG.xxxxxxxxxxxxxxxxxxxx
```

API keys are created in the SendGrid Console under Settings > API Keys. Three permission levels:
- **Full Access** — all endpoints
- **Restricted Access** — per-endpoint granular permissions
- **Billing Access** — billing endpoints only

The `@sendgrid/mail` SDK handles the header automatically via `sgMail.setApiKey()`.

---

## Mail Send

### `POST /v3/mail/send`

The primary endpoint. Returns `202 Accepted` on success (message queued, not delivered).

#### Request Body Schema

```json
{
  "personalizations": [
    {
      "to": [{ "email": "string", "name": "string" }],
      "cc": [{ "email": "string", "name": "string" }],
      "bcc": [{ "email": "string", "name": "string" }],
      "subject": "string",
      "headers": { "X-Custom-Header": "value" },
      "substitutions": { "-name-": "Alice" },
      "dynamic_template_data": { "key": "value" },
      "custom_args": { "campaign": "welcome" },
      "send_at": 1234567890
    }
  ],
  "from": { "email": "string", "name": "string" },
  "reply_to": { "email": "string", "name": "string" },
  "reply_to_list": [{ "email": "string", "name": "string" }],
  "subject": "string",
  "content": [
    { "type": "text/plain", "value": "string" },
    { "type": "text/html", "value": "string" }
  ],
  "attachments": [
    {
      "content": "base64-encoded-string",
      "type": "application/pdf",
      "filename": "invoice.pdf",
      "disposition": "attachment",
      "content_id": "invoice"
    }
  ],
  "template_id": "d-xxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "headers": { "X-Custom-Header": "value" },
  "categories": ["transactional", "order-confirmation"],
  "custom_args": { "user_id": "12345" },
  "send_at": 1234567890,
  "batch_id": "string",
  "asm": {
    "group_id": 12345,
    "groups_to_display": [12345, 67890]
  },
  "ip_pool_name": "string",
  "mail_settings": {
    "bypass_list_management": { "enable": false },
    "bypass_spam_management": { "enable": false },
    "bypass_bounce_management": { "enable": false },
    "bypass_unsubscribe_management": { "enable": false },
    "footer": { "enable": true, "text": "string", "html": "string" },
    "sandbox_mode": { "enable": false }
  },
  "tracking_settings": {
    "click_tracking": { "enable": true, "enable_text": false },
    "open_tracking": { "enable": true, "substitution_tag": "%open-track%" },
    "subscription_tracking": {
      "enable": true,
      "text": "Unsubscribe: <%asm_group_unsubscribe_raw_url%>",
      "html": "<a href='<%asm_group_unsubscribe_raw_url%>'>Unsubscribe</a>",
      "substitution_tag": "%unsub%"
    },
    "ganalytics": {
      "enable": true,
      "utm_source": "sendgrid",
      "utm_medium": "email",
      "utm_term": "",
      "utm_content": "",
      "utm_campaign": "campaign-name"
    }
  }
}
```

#### Limits

| Constraint | Limit |
|------------|-------|
| Personalizations per request | 1,000 |
| Recipients per personalization (`to` + `cc` + `bcc`) | 1,000 |
| Total recipients per request | 1,000 |
| Categories per message | 10 |
| Custom args total size | 10,000 bytes |
| Subject line length | 998 characters (RFC 2822) |
| Total message size (including attachments) | 30 MB |
| Attachment file size after base64 encoding | ~22 MB raw (30 MB encoded) |
| `send_at` max scheduling window | 72 hours from now |
| `reply_to_list` max entries | 1,000 |

#### Response Codes

| Code | Meaning |
|------|---------|
| `202 Accepted` | Message queued for processing |
| `400 Bad Request` | Invalid request body (check `errors` array) |
| `401 Unauthorized` | Invalid or missing API key |
| `403 Forbidden` | API key lacks required permissions |
| `404 Not Found` | Invalid endpoint |
| `413 Payload Too Large` | Exceeds 30MB (empty body, no error details) |
| `429 Too Many Requests` | Rate limited — back off exponentially |
| `500 Internal Server Error` | SendGrid server error — retry with backoff |

#### Error Response Format

```json
{
  "errors": [
    {
      "message": "The from email does not contain a valid address.",
      "field": "from.email",
      "help": "http://sendgrid.com/docs/API_Reference/Web_API_v3/Mail/errors.html"
    }
  ]
}
```

---

## Batch IDs (Scheduled Send Management)

### `POST /v3/mail/batch`

Generate a batch ID for scheduled send cancellation.

**Response**: `{ "batch_id": "string" }`

### `POST /v3/user/scheduled_sends`

Cancel or pause a scheduled batch.

```json
{
  "batch_id": "YWJjZGVmZw",
  "status": "cancel"
}
```

Status values: `cancel` (discard), `pause` (hold)

### `GET /v3/user/scheduled_sends`

List all scheduled send cancellations/pauses.

### `DELETE /v3/user/scheduled_sends/{batch_id}`

Remove a cancel/pause — resume scheduled sending.

---

## Dynamic Templates

### `GET /v3/templates?generations=dynamic`

List dynamic templates. The `generations=dynamic` parameter filters to Handlebars templates.

### `GET /v3/templates/{template_id}`

Get template metadata and version list.

### Template Version Operations

- `POST /v3/templates/{id}/versions` — Create version
- `GET /v3/templates/{id}/versions/{version_id}` — Get version
- `PATCH /v3/templates/{id}/versions/{version_id}` — Update version
- `DELETE /v3/templates/{id}/versions/{version_id}` — Delete version
- `POST /v3/templates/{id}/versions/{version_id}/activate` — Activate version

### Handlebars Helpers Available

| Helper | Usage | Example |
|--------|-------|---------|
| `if` | Conditional | `{{#if show_banner}}...{{/if}}` |
| `unless` | Inverse conditional | `{{#unless opted_out}}...{{/unless}}` |
| `each` | Iteration | `{{#each items}}{{this.name}}{{/each}}` |
| `equals` | Equality check | `{{#equals status "active"}}...{{/equals}}` |
| `notEquals` | Inequality | `{{#notEquals role "admin"}}...{{/notEquals}}` |
| `and` | Logical AND | `{{#and condition1 condition2}}...{{/and}}` |
| `or` | Logical OR | `{{#or condition1 condition2}}...{{/or}}` |
| `greaterThan` | Numeric compare | `{{#greaterThan count 5}}...{{/greaterThan}}` |
| `lessThan` | Numeric compare | `{{#lessThan count 5}}...{{/lessThan}}` |
| `length` | Array/string length | `{{length items}}` |
| `formatDate` | Date formatting | `{{formatDate date "MM/DD/YYYY"}}` |
| `insert` | Insert module | `{{insert "module_name"}}` |

Unsupported: custom helpers, inline partials, `lookup`, `log`, `with`, `blockHelperMissing`.

---

## Suppressions

### Bounces

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/v3/suppression/bounces` | List all bounces |
| `GET` | `/v3/suppression/bounces/{email}` | Get specific bounce |
| `DELETE` | `/v3/suppression/bounces/{email}` | Remove bounce record |

### Blocks

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/v3/suppression/blocks` | List all blocks |
| `DELETE` | `/v3/suppression/blocks/{email}` | Remove block record |

### Spam Reports

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/v3/suppression/spam_reports` | List spam reports |
| `DELETE` | `/v3/suppression/spam_reports/{email}` | Remove spam report |

### Invalid Emails

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/v3/suppression/invalid_emails` | List invalid emails |
| `DELETE` | `/v3/suppression/invalid_emails/{email}` | Remove invalid record |

### Global Unsubscribes

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/v3/suppression/unsubscribes` | List global unsubscribes |
| `POST` | `/v3/asm/suppressions/global` | Add global unsubscribe |
| `DELETE` | `/v3/asm/suppressions/global/{email}` | Remove global unsubscribe |

### ASM (Suppression Groups)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/v3/asm/groups` | List suppression groups |
| `POST` | `/v3/asm/groups` | Create suppression group |
| `GET` | `/v3/asm/groups/{group_id}/suppressions` | List group suppressions |
| `POST` | `/v3/asm/groups/{group_id}/suppressions` | Add to group |
| `DELETE` | `/v3/asm/groups/{group_id}/suppressions/{email}` | Remove from group |

---

## Email Validation

### `POST /v3/validations/email`

Validate an email address (paid add-on, not included in all plans).

**Request**: `{ "email": "test@example.com", "source": "signup" }`

**Response**:
```json
{
  "result": {
    "email": "test@example.com",
    "verdict": "Valid",
    "score": 0.95,
    "local": "test",
    "host": "example.com",
    "checks": {
      "domain": { "has_valid_address_syntax": true, "has_mx_or_a_record": true },
      "local_part": { "is_suspected_role_address": false },
      "additional": { "has_known_bounces": false, "has_suspected_bounces": false }
    },
    "ip_address": "1.2.3.4"
  }
}
```

Verdict values: `Valid`, `Risky`, `Invalid`

---

## Domain Authentication

### `POST /v3/whitelabel/domains`

Initiate domain authentication.

### `GET /v3/whitelabel/domains/{id}/validate`

Check if DNS records are properly configured.

Required DNS records (CNAME):
1. `s1._domainkey.yourdomain.com` → `s1.domainkey.u1234.wl.sendgrid.net`
2. `s2._domainkey.yourdomain.com` → `s2.domainkey.u1234.wl.sendgrid.net`
3. `em1234.yourdomain.com` → `u1234.wl.sendgrid.net` (return path)

---

## Stats & Activity

### `GET /v3/stats`

Global email stats (requests, delivered, bounces, opens, clicks, etc.).

Query parameters: `start_date` (required), `end_date`, `aggregated_by` (day/week/month).

### `GET /v3/messages`

Email Activity Feed (requires Email Activity add-on). Search by `msg_id`, `from_email`, `to_email`, `subject`, `status`. Retention: 30 days.

### `GET /v3/messages/{msg_id}`

Get details for a specific message including all events.
