---
name: compliance-and-enterprise
description: PII redaction, HIPAA, PCI, Language Operators, scaling limits, and HA/DR guidance for Twilio voice applications.
---

# Compliance, Language Operators, and Enterprise Considerations

PII redaction, HIPAA, PCI, Language Operators, scaling limits, and HA/DR guidance.

See [SKILL.md](../SKILL.md) for the cross-cutting gotchas summary.

---

## PII Redaction and HIPAA Guidance

### Voice Intelligence PII Redaction

Voice Intelligence supports two levels of PII redaction:

| Type | Scope | Languages | How |
|------|-------|-----------|-----|
| **Text redaction** | Transcript text | All supported | Replaces PII with `[REDACTED]` in transcript sentences |
| **Audio redaction** | Recording audio | `en-US` only | Bleeps out PII segments in the audio file |

Configure via the Intelligence Service settings in Console or API:
- `pii_redaction_enabled: true` — enables text-level redaction
- `audio_redaction_enabled: true` — enables audio-level redaction (en-US only)

### HIPAA Considerations

- **BAA required**: You must have a Business Associate Agreement with Twilio before processing PHI
- **Recording storage**: Use recording encryption and set appropriate TTLs
- **Transcript access**: Restrict API key access to transcripts containing PHI
- **PII in logs**: Twilio debugger logs may contain phone numbers and partial message content; rotate API keys regularly

### PCI DSS

- **Never record card numbers**: Use `<Pay>` verb for payment capture; it handles PCI compliance
- **Recording pause**: If you must take payment during a recorded call, use `<Pause>` recording during payment segment
- **PCI Mode**: Enabling PCI Mode on a Twilio account is IRREVERSIBLE and account-wide

---

## Language Operator Configuration

Language Operators run post-processing on Voice Intelligence transcripts. Configure them on your Intelligence Service.

### Available Operator Types

| Type | Purpose | Example Output |
|------|---------|---------------|
| `text-generation` | Summarize or extract from transcript | Free-text summary |
| `classification` | Categorize into predefined labels | `"billing"`, `"support"`, `"sales"` |
| `extraction` | Pull structured entities | `{"name": "John", "account": "12345"}` |

### Configuration Example

Operators are attached to an Intelligence Service. When a transcript is created under that service, all attached operators run automatically.

```
Intelligence Service (GA...)
  └── Operator: "Call Summary" (text-generation)
  └── Operator: "Topic Classification" (classification, labels: billing/support/sales/other)
  └── Operator: "Entity Extraction" (extraction, entities: name/account/phone)
```

### Validation

Use `validate_language_operator` to verify operator results exist after transcript completion. Check:
- Operator result count matches expected operator count
- Text-generation results have non-empty content
- Classification results return valid labels

---

## Enterprise Considerations

### Scaling Limitations

Twilio Serverless Functions have built-in constraints relevant to production deployments:

| Limit | Value | Impact |
|-------|-------|--------|
| Concurrent executions | 30 per service | Contact centers with >30 simultaneous calls need multiple services or external compute |
| Execution timeout | 10 seconds | Long-running operations (transcription polling, multi-API orchestration) must use callbacks |
| Memory | 256 MB | Large audio processing should happen externally |
| Deployment size | 50 MB | Limit dependencies; use external packages via layers if needed |

### When Functions Aren't Enough

For production contact centers or high-volume voice applications, consider:
- **External compute** (AWS Lambda, GCP Cloud Functions, self-hosted) for webhook handlers
- **Twilio Functions for TwiML only** — keep webhook handlers thin, delegate business logic
- **Flex** for full-featured contact center with agent UI

### HA/DR Guidance

- **Multi-region**: Twilio processes calls in the region closest to the caller by default. For explicit region control, use `TWILIO_EDGE` environment variable
- **Failover webhooks**: Configure `voiceFallbackUrl` and `smsFallbackUrl` on phone numbers for webhook failure recovery
- **Status callbacks**: Always configure `statusCallback` on calls; without it, failures are silent
- **Recording redundancy**: Download recordings to your own storage; Twilio keeps recordings indefinitely until explicitly deleted via the Recording API (see Recording Retention & Encryption below)

### ConversationRelay Resilience

ConversationRelay adds WebSocket and LLM dependencies beyond standard voice HA/DR:

- **WebSocket server redundancy**: Deploy multiple WebSocket server instances behind a load balancer. Twilio connects to a single `wss://` URL — the LB distributes across healthy instances
- **`action` URL fallback**: Configure an `action` URL on the `<Connect>` verb. When the WebSocket disconnects (server crash, network partition), Twilio fetches TwiML from the action URL instead of ending the call. Use this for graceful degradation to DTMF IVR or a "please hold" message while reconnecting
- **LLM provider failover**: If your primary LLM provider is down, your WebSocket server should detect timeouts and fall back to a secondary provider or a scripted response. Twilio has no awareness of LLM state — this is entirely in your server logic
- **Session state persistence**: WebSocket disconnection loses all in-memory conversation state. Persist conversation history and context to Sync Documents or an external store (Redis, DynamoDB) so a reconnected session can resume. Without this, a reconnect starts a fresh conversation
- **Canary deployments**: Deploy prompt changes to a percentage of new calls before rolling out fully. A bad prompt change on a live ConversationRelay deployment affects every call immediately

---

## Recording Retention & Encryption

### Default Retention

Twilio voice recordings are kept until explicitly deleted. There is no automatic expiration or TTL on voice recordings — they persist on Twilio's infrastructure indefinitely unless you delete them via the Recording API (`DELETE /2010-04-01/Accounts/{sid}/Recordings/{sid}.json`).

### Custom Retention Policies

For regulatory retention requirements (7-year SOX, 6-year HIPAA, industry-specific mandates), implement your own retention pipeline:

1. **Download recordings** to your own storage (S3, GCS, Azure Blob) immediately after creation via `recordingStatusCallback`
2. **Apply your retention policy** in your storage layer — lifecycle rules, legal holds, versioning
3. **Delete from Twilio** on your schedule using the Recording API to minimize storage costs

Twilio does not provide built-in retention policy configuration (e.g., "auto-delete after N days"). Scheduled deletion is your application's responsibility.

### Encryption

| Layer | Protection | How |
|-------|-----------|-----|
| **At rest** | Recordings encrypted on Twilio's infrastructure | Enabled by default. Twilio manages the encryption keys. |
| **In transit (API)** | TLS for all API calls | All Recording API requests use HTTPS. |
| **In transit (media)** | SRTP when Secure Media is enabled | Enable `secure: true` on SIP Trunks for SRTP media encryption. For Programmable Voice calls, media is encrypted in transit by default. |

**Scope boundary**: Twilio encrypts recordings at rest by default using Twilio-managed keys. Bring Your Own Key (BYOK) / Customer Managed Keys (CMK) for recording encryption is not available. If your compliance requirements mandate customer-managed encryption keys, download recordings to your own storage and encrypt with your own KMS.

---

## Transcription at Enterprise Scale

### Real-Time vs Post-Call

| Approach | Mechanism | Volume Impact | When to Use |
|----------|-----------|---------------|-------------|
| **Real-time** (`<Start><Transcription>`) | Each utterance fires an HTTP callback to your `statusCallbackUrl` | High webhook volume — one request per speech segment per call | Live monitoring, real-time captions, compliance triggers during call |
| **Post-call** (Voice Intelligence) | Recording submitted to Intelligence Service after call ends | One API call per recording; operators run asynchronously | Summarization, sentiment analysis, entity extraction, batch analytics |

For enterprise scale, prefer post-call Voice Intelligence for analytics workloads. Reserve real-time `<Start><Transcription>` for use cases that genuinely require in-call processing.

### Language Operator Considerations at Scale

- **Quotas**: Check current operator limits in Console. Operator execution is asynchronous — results appear after transcript processing completes, not instantly.
- **Custom operators**: Create custom operators (text-generation, classification, extraction) via the Intelligence Service API. Each operator attached to a service runs on every transcript created under that service.
- **Engine selection**: Twilio Voice Intelligence uses speech-to-text engines that affect cost and accuracy. Engine availability and pricing may vary — check current Console settings for your Intelligence Service.
- **False positive tuning**: For classification and extraction operators, refine prompts and labels iteratively. There is no built-in false positive rate metric — evaluate operator accuracy against your own labeled dataset.

### Aggregation Pipeline

Twilio provides per-call transcription and per-transcript operator results. Aggregation across calls — feeding transcripts to Kafka, a data warehouse, or a search index — is your infrastructure:

1. **Webhook receiver**: Handle transcription completion callbacks (via Intelligence Service webhooks or Event Streams) or poll the Transcript API
2. **Transform**: Extract operator results, transcript sentences, and metadata
3. **Load**: Push to your analytics pipeline (Kafka, BigQuery, Snowflake, Elasticsearch)

**Scope boundary**: Twilio provides per-call transcription and Language Operators. Aggregation pipelines (streaming to Kafka, data warehouse loading, cross-call analytics, A/B testing for engine accuracy) are your application's responsibility. Event Streams can feed real-time call events to a Webhook or Kinesis sink, but transcript content is not included in Event Streams — use the Transcript API or callbacks.

---

## Debt Collection Compliance (FDCPA / Regulation F)

Use Case 4 (Outbound Contact Center) covers TCPA for general outbound calling. Debt collection introduces additional federal requirements under the Fair Debt Collection Practices Act (FDCPA) and its implementing rule, Regulation F (effective November 2021).

### Applicability

- **FDCPA applies to third-party debt collectors** — agencies collecting on behalf of another creditor. Original creditors collecting their own debts are generally not covered by FDCPA (but may be covered by state laws).
- **Regulation F** (12 CFR 1006) implements FDCPA and adds specific requirements for modern communication channels (calls, SMS, email, voicemail).

### Key Requirements

| Requirement | Rule | Implementation Responsibility |
|-------------|------|-------------------------------|
| **Contact frequency limits** | Max 7 call attempts per debt per 7-day rolling period. After a live conversation, no further attempts for 7 days on that debt. | Your application — track attempts per debt in your database. Twilio does not enforce frequency caps. |
| **Mini-Miranda disclosure** | Every communication must include a standard statement identifying the caller as a debt collector (e.g., "This is an attempt to collect a debt. Any information obtained will be used for that purpose."). | Your application — include required disclosures in call scripts, voicemail drops, and SMS templates. |
| **Voicemail requirements** | Voicemails must include the mini-Miranda disclosure. "Limited-content messages" (name, phone number, no debt details) are an alternative to avoid third-party disclosure risk. | Your application — design voicemail scripts for both full and limited-content variants. Use AMD (Answering Machine Detection) to detect voicemail and select the appropriate message. |
| **SMS opt-in** | SMS consent for debt collection is separate from call consent. Must provide opt-out mechanism in every message. Regulation F treats SMS as an "electronic communication" with specific disclosure requirements. | Your application — maintain separate SMS consent records. Use Twilio's opt-out handling (STOP keyword) but track consent independently for Reg F compliance. |
| **Time-of-day restrictions** | No calls before 8 AM or after 9 PM in the consumer's local time zone (same as TCPA, but FDCPA predates TCPA). | Your application — same implementation as TCPA quiet hours (see UC7 TCPA Calling Window). |
| **Cease and desist** | Consumer can request in writing that collector stop all communication. Collector must comply (with limited exceptions for legal notices). | Your application — maintain a per-consumer suppression list separate from DNC. |

### Scope Boundary

Twilio provides the communication channel — voice calls, SMS, voicemail drops via AMD. FDCPA and Regulation F compliance logic is entirely your application's responsibility:

- **Frequency caps**: Track call attempts per debt per 7-day window in your database
- **Disclosure scripts**: Author mini-Miranda language for calls, voicemail, and SMS
- **Consent management**: Maintain separate consent records for voice and SMS per Regulation F
- **Suppression lists**: Implement cease-and-desist tracking independent of DNC registries

Twilio does not provide a built-in debt collection compliance engine, frequency cap enforcement, or disclosure template management. These are application-layer concerns that use Twilio as the underlying transport.
