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

**Evidence**: Live-tested 2026-03-25 against GlobalTech Solutions test IVR. 22 calls, 22 nodes, 10m 44s, 100% completion. Account ACb4de...

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
- Navigate IVRs requiring authentication (account numbers, PINs, SSNs)
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
| Test our own IVR | Call `+12066664151` (GlobalTech test IVR) or crawl it |
| Debug a failed crawl | Check `validate_call(callSid)` for the failing call |

## Prerequisites

Before running a crawl, verify:

1. **ngrok running**: `ngrok http 8080` — provides the public WebSocket URL for ConversationRelay
2. **Environment variables set** in `.env`:
   - `TWILIO_ACCOUNT_SID` and `TWILIO_AUTH_TOKEN`
   - `TWILIO_PHONE_NUMBER` (outbound caller ID)
   - `ANTHROPIC_API_KEY` (for Claude prompt analysis)
3. **Crawler built**: `cd agents/ivr-crawler && npm install && npx tsc`
4. **Target IVR accessible**: The phone number must be callable from your Twilio number

## Usage

```bash
# Start ngrok (separate terminal or background)
ngrok http 8080

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

## How It Works

1. **WebSocket server starts** on localhost, exposed via ngrok
2. **Outbound call** placed to target IVR with inline ConversationRelay TwiML
3. **`sendDigits`** on `calls.create()` sends RFC 2833 DTMF to navigate the IVR to a specific menu position
4. **ConversationRelay** transcribes the IVR prompt → WebSocket → text
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

1. **sendDigits timing varies per IVR**: If digits arrive before a `<Gather>` is active, they're ignored. Increase `--silence-timeout` and the initial delay in `buildSendDigits()` for slow IVRs.
2. **ConversationRelay needs Deepgram**: The crawler uses `transcriptionProvider="deepgram"` with `speechModel="nova-3-general"`. Google STT also works but Deepgram is the project standard.
3. **Agent transfers fail without CR WebSocket server**: If the target IVR transfers to a ConversationRelay agent, it needs a running WebSocket server. Without `CONVERSATION_RELAY_URL`, transfers show as errors.
4. **ngrok URL changes on restart**: Each ngrok session gets a new URL. The `--ws-url` must match the current ngrok tunnel.
5. **Cost**: ~$0.02/call + ~$0.01/Claude analysis. A 30-node IVR costs ~$1.00-$1.50 total.
6. **Root prompt accumulation**: The silence timer must be long enough for the IVR to play both the greeting and the menu prompt. Default 3s works for most IVRs; use 5-8s for IVRs with long greetings.

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

## Reference Files

| Topic | File | When to read |
|-------|------|-------------|
| IvrTree JSON schema | `references/tree-schema.md` | When consuming crawler output |
