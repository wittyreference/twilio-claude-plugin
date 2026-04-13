---
name: "ivr-crawler"
description: "Twilio development skill: ivr-crawler"
---

---
name: ivr-crawler
description: Crawl and map IVR phone trees autonomously. Use when mapping an existing IVR system, migrating an IVR to Twilio, or analyzing IVR structure. Triggers on "crawl IVR", "map IVR", "IVR migration", "replicate IVR".
---

# IVR Crawler

Autonomously maps any IVR phone system by calling it, navigating every branch via DTMF, and producing a structured tree. The output feeds `/ivr-migrator` to rebuild the IVR on Twilio.

**Evidence**: Live-tested 2026-03-25 against GlobalTech Solutions test IVR. 22 calls, 22 nodes, 10m 44s, 100% completion. Account ACxx...xx

## Scope

### CAN
- Crawl any phone number's IVR via outbound calls
- Navigate menus using DTMF (`sendDigits` on `calls.create()`)
- Detect menu options, dead ends, transfers, hold music, callbacks, business hours
- Handle multi-language IVRs (detected per-node via Claude analysis)
- Detect cycles (return-to-menu, redirects) and avoid infinite exploration
- Output structured JSON (`IvrTree`) and ASCII tree visualization
- Speak through ConversationRelay for speech-only menus
- Generate VoiceXML 2.1 from crawl output (VXML generator)
- Parse customer-provided VXML documents into IvrTree IR (VXML parser)
- Generate Twilio Serverless Functions from VXML (full VXML-to-TwiML pipeline)
- Round-trip validation: IvrTree → VXML → parse → TwiML → deploy → crawl → compare

### CANNOT
- Navigate auth-protected IVRs without test credentials — but CAN navigate payment IVRs when test data (account, ZIP, card) is provided via scenario configuration
- Interact with IVRs that use only speech recognition (no DTMF) beyond basic keyword navigation
- Guarantee timing alignment with every IVR (some need longer `sendDigits` delays)
- Make calls without a Twilio phone number and valid credentials
- Run without ngrok or another WebSocket tunnel

## Quick Decision

| Need | Action |
|------|--------|
| Map an existing IVR | Run `/ivr-crawler` with the phone number |
| Migrate IVR to Twilio | Run `/ivr-crawler` first, then `/ivr-migrator` on the output |
| Customer has VXML docs | Parse VXML → IvrTree IR → generate TwiML handlers directly |
| Generate VXML from crawl | Use `generateVxml(tree)` to create VoiceXML for customer review |
| Test our own IVR | Call `+15550100009` (GlobalTech test IVR) or crawl it |
| Debug a failed crawl | Check `validate_call(callSid)` for the failing call |

## Prerequisites

Before running a crawl, verify:

1. **ngrok running**: `ngrok http --domain=ff-crawler.ngrok.dev 8083` — port 8083 per D45 registry, provides the public WebSocket URL for ConversationRelay
2. **Environment variables set** in `.env`:
   - `TWILIO_ACCOUNT_SID` and `TWILIO_AUTH_TOKEN`
   - `TWILIO_PHONE_NUMBER` (outbound caller ID)
   - `ANTHROPIC_API_KEY` (for Claude prompt analysis)
3. **Crawler built**: `cd agents/ivr-crawler && npm install && npx tsc`
4. **Target IVR accessible**: The phone number must be callable from your Twilio number

## Usage

```bash
# Start ngrok (separate terminal or background)
ngrok http --domain=ff-crawler.ngrok.dev 8083

# Run the crawler
cd agents/ivr-crawler
node dist/index.js crawl <TARGET_NUMBER> \
  --ws-url wss://<NGROK_SUBDOMAIN>.ngrok-free.dev \
  --from +1XXXXXXXXXX \
  --output ./ivr-tree.json
```

### CLI Options

| Option | Default | Description |
|--------|---------|-------------|
| `--from <number>` | `$TWILIO_PHONE_NUMBER` | Outbound caller ID (E.164) |
| `--port <number>` | `8080` | Local WebSocket server port |
| `--ws-url <url>` | Required | ngrok WSS URL for ConversationRelay |
| `--max-calls <n>` | `50` | Safety limit on total outbound calls |
| `--max-depth <n>` | `6` | Maximum IVR tree depth to explore |
| `--call-delay <ms>` | `1500` | Delay between calls (rate limiting) |
| `--silence-timeout <ms>` | `3000` | Silence after prompt to consider complete |
| `--prompt-timeout <ms>` | `15000` | Max wait for IVR prompt |
| `--output <path>` | `./ivr-tree.json` | Output JSON file path |
| `--model <model>` | `claude-sonnet-4-20250514` | Claude model for analysis |

### Recommended Settings for Different IVR Types

| IVR Type | Settings |
|----------|----------|
| Fast/simple (< 10 nodes) | `--max-calls 20 --silence-timeout 3000` |
| Complex corporate (20-50 nodes) | `--max-calls 50 --silence-timeout 5000 --call-delay 2000` |
| Slow/long-greeting IVR | `--silence-timeout 8000 --prompt-timeout 30000` |


## Scenario-Driven Crawling (Branch Coverage)

The standard RTT crawler (`explore-rtt.mjs`) follows one path per call. For comprehensive IVR mapping, use `explore-rtt-scenarios.mjs` which runs predefined test scenarios to exercise every branch.

### Usage

```bash
# Single scenario
NGROK_DOMAIN_CRAWLER=ff-crawler.ngrok.dev node explore-rtt-scenarios.mjs +1844NNNNNNN success-even "My IVR"

# All scenarios sequentially
NGROK_DOMAIN_CRAWLER=ff-crawler.ngrok.dev node explore-rtt-scenarios.mjs +1844NNNNNNN all "My IVR"
```

### Predefined Scenarios

| Key | Purpose | Test Data |
|-----|---------|-----------|
| `success-even` | Authorize (even amount) | $100.00, real-BIN Visa card |
| `success-preset-total` | Preset amount option 1 | $14.04 total due |
| `success-bank` | Bank payment path | Checking account, routing 021000021 |
| `fail-odd-amount` | Decline (odd amount) | $99.00 |
| `fail-blocked-card` | Blocklisted card | 4111111111111111 |
| `wrong-account` | Invalid account | 1234567890 |
| `wrong-zip` | Invalid ZIP | 00000 |
| `confirm-incorrect` | Re-entry path | Press 2 on first confirm |

### Adding Custom Scenarios

Add to the SCENARIOS object in explore-rtt-scenarios.mjs. Each scenario defines: account, zip, card, expiry, cvv, amount, paymentOption, paymentMethod, confirmAction.

## Two Crawling Architectures

The crawler evolved through four attempts (documented in `analysis/ivr-crawler-showcase.md`). Two architectures survived, each suited to different IVR types.

### Architecture 1: BFS Multi-Call (`--mode cr` or `--mode transcription`)

**How it works**: One outbound call per tree node. `sendDigits` on `calls.create()` replays the full digit path from root to reach each menu position. ConversationRelay or Media Streams captures the prompt. BFS explores all branches.

**Strength**: Stateless and deterministic — each call is independent, no mid-call state to manage. Handles menu-style IVRs with fixed digit paths.

**Limitation**: Cannot handle sequential-input IVRs (payment flows, account verification) where each step depends on the previous response. `sendDigits` on `calls.create()` fires once at call start; there's no way to send DTMF mid-call in response to what the IVR says.

**Audio capture options** (all validated 15/15 via `diagnose-audio.mjs`):

| Method | Flag | Needs | When to use |
|--------|------|-------|-------------|
| **ConversationRelay** | `--mode cr` | WS + ngrok | Default. Built-in STT, bidirectional (can speak back for speech IVRs, apologize to humans) |
| **Media Streams + Deepgram** | `--mode transcription` | WS + ngrok + `DEEPGRAM_API_KEY` | Per-track control, custom STT, no CR access needed |

### Architecture 2: RTT Ping-Pong (single call)

**How it works**: One call navigates the entire IVR. `<Start><Transcription>` begins at call start and **persists as a background operation across TwiML changes**. The call ping-pongs between three TwiML states:

```
<Start><Transcription> → listen for prompt via RTT callbacks
  → <Play digits="w1"> → send DTMF to IVR (in-band audio tones)
  → <Redirect> back to handler → listen for next prompt
  → <Play digits="ww2"> → next DTMF
  → <Redirect> → listen...
```

**Strength**: Can handle sequential-input IVRs (enter account number → confirm → enter ZIP → etc.) because it sends DTMF mid-call in response to each prompt. Single call = lower cost and faster.

**Limitation**: `<Play digits>` generates in-band audio tones, not RFC 2833 signaling. Most IVRs detect them, but some don't. Long digit sequences (16-digit card numbers) may drop a digit. Needs an HTTP server for RTT callbacks + a deployed function to serve the ping-pong TwiML.

**Implementation**: `explore-rtt.mjs` (DTMF) and `explore-rtt-voice.mjs` (speech + DTMF). These are standalone exploration scripts, not integrated into the BFS crawler CLI.

### Which architecture to use

| IVR Type | Architecture | Why |
|----------|-------------|-----|
| Menu tree ("press 1 for sales") | **BFS Multi-Call** | Fixed digit paths, stateless, full tree mapping |
| Sequential input (account#, ZIP, card) | **RTT Ping-Pong** | Mid-call DTMF needed, each step depends on prior response |
| Speech-only ("say your name") | **BFS + CR** | ConversationRelay can speak back via TTS |
| Mixed (menus + payment flow) | **Both** | BFS maps the menu tree, RTT handles the payment subflow |
| Unknown IVR type | **BFS first** | Map what you can, switch to RTT if sequential input detected |

### Critical: ngrok tunnel hygiene

All real-time methods require a clean ngrok tunnel. **Duplicate tunnels on the same domain cause silent, intermittent failures** — requests route unpredictably between ports. Before any crawl:

```bash
# Verify exactly ONE tunnel for your domain
curl -s http://localhost:4040/api/tunnels | python3 -c "
import json, sys
for t in json.load(sys.stdin).get('tunnels', []):
    if 'crawler' in t['name']: print(f\"{t['name']}: {t['public_url']} -> {t['config']['addr']}\")
"
# Must show exactly 1 line. If >1, delete extras via ngrok API.
```

## How BFS Multi-Call Works

1. **Server starts** on localhost, exposed via ngrok (WS for CR/Streams)
2. **Outbound call** placed to target IVR with inline TwiML
3. **`sendDigits`** on `calls.create()` sends RFC 2833 DTMF to navigate the IVR to a specific menu position
4. **Audio capture** transcribes the IVR prompt via the configured method
5. **Claude API** analyzes the prompt: identifies node type, menu options, language
6. **TreeBuilder** records the node, queues unexplored branches
7. **BFS loop** repeats until all branches explored or limits hit
8. **Cycle detection** compares option digit sets against existing nodes to detect redirects
9. **Output**: JSON tree + ASCII visualization + statistics

### sendDigits Timing

Format: `WWWWW1WW2WW3` (5s initial delay, 2s between digits)
- `W` = 1-second pause (vs `w` = 0.5s)
- Initial `WWWWW` gives IVR greeting time to finish before first Gather
- `WW` between digits allows IVR to process and present next menu
- Max 32 characters = ~10 levels deep

## Output Format

The crawler produces an `IvrTree` JSON file. See [references/tree-schema.md](references/tree-schema.md) for the full schema.

Key node types: `root`, `menu`, `information`, `transfer`, `dead_end`, `callback`, `hold_music`, `hours_check`, `voicemail`, `error`, `timeout`

## Gotchas

1. **Duplicate ngrok tunnels cause silent failures**: If two tunnels exist for the same domain (e.g., one on port 8080, another on 8089), requests route unpredictably. CR connects (setup message arrives) but prompts silently don't flow. Always verify exactly one tunnel before crawling. This cost 3+ hours of debugging in the 2026-04-06 session.
2. **ngrok 404 looks like your server's 404**: When the ngrok endpoint is offline, it returns HTTP 404 with an HTML error page — not a connection error. Check the response BODY, not just the status code.
3. **sendDigits timing varies per IVR**: If digits arrive before a `<Gather>` is active, they're ignored. Increase `--silence-timeout` and the initial delay in `buildSendDigits()` for slow IVRs.
4. **ConversationRelay needs Deepgram**: The crawler uses `transcriptionProvider="deepgram"` with `speechModel="nova-3-general"`. Google STT also works but Deepgram is the project standard.
5. **Media Streams mode needs DEEPGRAM_API_KEY**: The `--mode transcription` path requires a Deepgram API key in `.env` for streaming STT.
6. **Agent transfers fail without CR WebSocket server**: If the target IVR transfers to a ConversationRelay agent, it needs a running WebSocket server. Without `CONVERSATION_RELAY_URL`, transfers show as errors.
7. **Cost**: ~$0.02/call + ~$0.01/Claude analysis. A 30-node IVR costs ~$1.00-$1.50 total.
8. **Root prompt accumulation**: The silence timer must be long enough for the IVR to play both the greeting and the menu prompt. Default 3s works for most IVRs; use 5-8s for IVRs with long greetings.
9. **When multiple products fail simultaneously, check infrastructure first**: If CR, RTT, and Streams all fail at once, the problem is ngrok/DNS/firewall — not the Twilio platform.

### Sequential Payment IVR Gotchas

10. **BFS crawler can't handle sequential payment flows** — Use RTT ping-pong for IVRs where each step depends on prior input (account → ZIP → balance → payment). BFS replays from root each call and can't carry state forward.

11. **IVR readback drops digits** — "770000007" for "7700000007" is normal. The IVR reads the number as a value, not digit-by-digit. The LLM navigator MUST be told to always confirm (press 1) regardless of readback accuracy.

12. **LLM navigator overrides explicit rules** — Even with "ALWAYS press 1, NEVER press 2" in the system prompt, Claude will second-guess confirmations if the readback looks wrong. Strengthen the prompt with: "CRITICAL: The readback WILL look wrong (missing zeros, truncated). This is NORMAL. Press 1 EVERY TIME."

13. **16-digit DTMF truncation** — Card numbers (16 digits) sent via `<Play digits>` consistently deliver only 14-15 digits to the IVR. This is a known timing/buffering limitation. Workaround: send digits in two 8-digit chunks (not yet implemented), or accept partial coverage of card-entry nodes.

14. **Test card validation** — Payment IVR test systems (e.g., BillMatrix) require:
    - Luhn-valid card number (mod 10 check digit)
    - Valid MID/BIN prefix (first 6 digits must map to a real issuer)
    - `4111111111111111` is universally blocklisted despite being Luhn-valid
    - Even dollar amount = authorize, odd = decline (BillMatrix-specific)

15. **Iterative node discovery** — First crawl maps the main path. Comprehensive coverage requires multiple scenario crawls exercising error paths, alternative payment methods, and edge cases. The Orange migration discovered 26 total nodes across 8 scenario runs (vs 15 from the initial single crawl).

16. **ngrok tunnels disappear** — Tunnels created via the ngrok API (not config file) are ephemeral. They disappear when the ngrok agent restarts. Always verify the tunnel exists before starting a crawl: `curl -s http://localhost:4040/api/tunnels`.

## VXML Pipeline

Three new modules complete the migration story:

| Module | File | Purpose |
|--------|------|---------|
| VXML Generator | `src/vxml-generator.ts` | IvrTree → VoiceXML 2.1 |
| VXML Parser | `src/vxml-parser.ts` | VoiceXML → IvrTree IR |
| VXML-to-TwiML | `src/vxml-to-twiml.ts` | IvrTree IR → Twilio Functions |

### Two migration paths

1. **Crawl path**: Phone number → crawl → IvrTree JSON → TwiML handlers (or VXML for customer review)
2. **VXML path**: Customer VXML docs → parse → IvrTree IR → TwiML handlers

### Round-trip validation

```
IvrTree → generateVxml() → parseVxml() → generateHandlers() → deploy → crawl → compare
```

Known lossy transformations through VXML round-trip:
- Free-form input nodes (account#, ZIP#) → VXML block+goto → parses as `information`
- Multiple edges pointing to same target → deduplicated to one edge
- DTMF + speech edges on same target → both preserved (digit + keywords)

## Related Resources

- **IVR Migrator**: `/ivr-migrator` — takes crawler output and generates Twilio Functions
- **Test IVR**: `test-ivr/CLAUDE.md` — GlobalTech Solutions test IVR (31 terminals, 3 languages)
- **Crawler Agent**: `CLAUDE.md` — agent source code and architecture
- **Voice Skill**: `skills/voice/SKILL.md` — TwiML patterns for generated IVR functions
- **ConversationRelay**: `CLAUDE.md` — WebSocket protocol reference
- **Orange IVR Migration**: `CLAUDE.md` — 22-handler reference implementation of a crawled-and-migrated payment IVR
- **Scenario Crawler**: `explore-rtt-scenarios.mjs` — branch coverage via test scenarios

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| IvrTree JSON schema | `references/tree-schema.md` | When consuming crawler output |
| Scenario crawler | `explore-rtt-scenarios.mjs` | When crawling payment or sequential-input IVRs |
