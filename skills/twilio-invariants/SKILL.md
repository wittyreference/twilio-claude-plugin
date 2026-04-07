---
name: "twilio-invariants"
description: "Twilio development invariants and rules"
---

---
paths:
  - "functions/**"
  - "__tests__/**"
---

# Serverless Function Invariants

Rules that have each caused real debugging time loss. See domain CLAUDE.md files for full context.

<architectural_invariants>
- **`Twilio.Response.setBody()` requires strings** — Passing objects causes `Buffer.from(object)` TypeError. Always `JSON.stringify()` + Content-Type header.
- **`console.error()` → 82005 alerts, `console.warn()` → 82004** — Use `console.log()` for ALL logging in Twilio Functions, including error conditions and catch blocks. Never use `console.error()` or `console.warn()` — they trigger debugger alerts that pollute monitoring and mask real issues. See `CLAUDE.md` (Logging Rules) for canonical policy.

- **Env vars can reset on deploy** — `twilio serverless:deploy` doesn't preserve runtime env vars. Always verify after deployment.
- **TwiML: one document controls a call at a time** — Updating a participant's TwiML exits their current state (conference, queue). Exception: `<Start><Stream>`, `<Start><Recording>`, `<Start><Siprec>` fork background processes.
- **`<Start><Recording>` syntax is `.recording()`, not `.record()`** — `twiml.start().recording({...})` is correct.
- **Empty `voiceUrl` on a Twilio number = silent instant call failure** — Calling a number with `voiceUrl: ""` produces `status: failed, duration: 0` with ZERO diagnostics. Always verify destination webhooks via `list_phone_numbers` before debugging call routing.
- **dotenv default mode doesn't override shell vars** — All project dotenv calls use `{ override: true }` so `.env` always wins. New dotenv usage must include `override: true`.
- **`<Pay>` silently ignored on outbound API call legs** — `<Pay>` in inline TwiML on `make_call` produces zero errors, zero callbacks. Must run from a phone number's voice URL webhook.
- **Conference DTMF is per-call, not cross-participant** — `<Play digits>` on one conference participant generates in-band audio. Cannot inject DTMF across conference participants.
- **Conference has no parent/child relationships** — Each participant is an independent call. One disconnecting doesn't affect others (unless `endConferenceOnExit=true`). Contrast with `<Dial>`-created calls where parent/child are coupled.
- **`<Pause>` as first TwiML verb = no-answer** — Webhook must produce audio (`<Say>`) before `<Pause>` to properly answer the call.
- **Video rooms require API Key auth** — AccessToken for Video uses API Key + Secret, not Auth Token. Functions must have TWILIO_API_KEY and TWILIO_API_SECRET env vars.
- **Never expose `accountSid` or `authToken` in function responses** — REST API credentials in browser JS or TwiML responses enable full account takeover. Use API Keys (`SK...`) for client-side auth. Server-side only: `context.ACCOUNT_SID`, `context.AUTH_TOKEN`.
- **`<Start><Transcription>` callbacks are form-encoded** — Transcription status callbacks arrive as `application/x-www-form-urlencoded`, NOT JSON. Parse fields from `event` directly (`event.TranscriptionText`, `event.TranscriptionSid`). Do not `JSON.parse()`.
- **Handler signature**: All Twilio Functions export `handler(context, event, callback)`. `context` provides env vars via `context.VARIABLE_NAME` and a pre-authenticated client via `context.getTwilioClient()`. `event` contains request parameters. `callback(error, response)` returns the response.
</architectural_invariants>

