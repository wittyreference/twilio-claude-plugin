# Twilio Claude Plugin

A Claude Code plugin that brings Twilio CPaaS expertise to any project. Provides specialized agents, commands, and skills for building voice, messaging, and real-time communication applications with Twilio.

## Prerequisites

The plugin requires these tools to be installed:

| Tool | Required Version | Purpose |
|------|-----------------|---------|
| Node.js | 20+ | Runtime for Twilio Functions |
| npm | (bundled with Node) | Package management |
| Twilio CLI | Latest | Deploy, manage numbers, debug |
| Serverless Plugin | Latest | `twilio serverless:start` and `serverless:deploy` |
| Claude Code | Latest | AI development environment |

**Quick install**: Run the dependency installer to check and install everything:

```bash
# Clone the plugin first, then run the installer
git clone https://github.com/wittyreference/twilio-claude-plugin.git
./twilio-claude-plugin/scripts/install-deps.sh
```

The script is idempotent — it skips anything already installed and never upgrades existing tools.

## Installation

Install directly from GitHub:

```bash
claude plugin add github:wittyreference/twilio-claude-plugin
```

Or clone and install locally:

```bash
git clone https://github.com/wittyreference/twilio-claude-plugin.git
claude plugin add ./twilio-claude-plugin
```

## Permissions

Some commands require specific Claude Code permissions:

| Command | Required Permission | Why |
|---------|---------------------|-----|
| `/twilio-docs` | `WebSearch`, `WebFetch` | Searches live Twilio documentation |
| `/twilio-logs` | `Bash` | Runs `twilio debugger:logs:list` CLI command |

If you encounter "auto-denied in dontAsk mode" errors, grant permissions via:
```bash
/permissions
```

Or add to your `~/.claude/settings.json`:
```json
{
  "permissions": {
    "allow": ["WebSearch", "WebFetch", "Bash"]
  }
}
```

## What's Included

### Slash Commands (User-Invocable)

These commands can be run directly in your Claude Code session:

| Command | Description | Permissions |
|---------|-------------|-------------|
| `/deploy [env]` | Deploy to Twilio Serverless with pre/post validation | Bash |
| `/test [scope]` | Run tests with coverage requirements | Bash |
| `/twilio-docs [topic]` | Search Twilio documentation | WebSearch |
| `/twilio-logs` | Fetch and analyze Twilio debugger logs | Bash |
| `/preflight` | Verify CLI profile, env vars, and auth before starting work | Bash |
| `/commit [scope]` | Stage and commit with pre-commit validation | Bash |
| `/push` | Push to remote with test verification | Bash |
| `/context [action]` | Context optimization — summarize, load, or analyze | — |
| `/validate [type] [SID]` | Deep validation of Twilio resources beyond HTTP 200 | — |
| `/wrap-up [scope]` | End-of-session review — capture learnings, update docs | — |

### Subagents (Claude-Invoked)

Claude automatically selects these specialized agents based on your task:

| Agent | Specialty |
|-------|-----------|
| **Architect** | System design, pattern selection, architecture decisions |
| **Spec** | Technical specification writing |
| **Test-Gen** | TDD Red Phase - writes failing tests first |
| **Dev** | TDD Green Phase - implements code to pass tests |
| **Review** | Code review with approval authority |
| **Docs** | Technical documentation updates |
| **Orchestrate** | Coordinates multi-agent workflows |

### Skills (Knowledge Files)

The plugin loads domain knowledge automatically when relevant:

**Twilio APIs:**
- `voice` - TwiML Voice verbs, webhooks, call handling
- `messaging` - SMS/MMS handling, status callbacks
- `verify` - OTP verification, 2FA flows
- `sync` - Real-time state with Documents, Lists, Maps
- `taskrouter` - Skills-based routing to workers
- `conversation-relay` - ConversationRelay for real-time voice AI with WebSocket
- `messaging-services` - Sender pools, A2P 10DLC compliance

**Reference:**
- `twilio-cli` - Comprehensive CLI command reference
- `twilio-invariants` - 9 proven gotchas that cause silent failures (credential formats, protocol fields, deployment traps)
- `voice-use-case-map` - Definitive product mapping for 10 voice use cases (notifications through AI transcription)
- `deep-validation` - Validation patterns beyond HTTP 200 (status polling, debugger checks, Voice Insights)
- `tdd-workflow` - TDD Red/Green/Refactor patterns for Twilio projects

**Context Engineering:**
- `context-fundamentals` - Context management principles
- `context-compression` - TwiML and payload compression
- `memory-systems` - State tracking across sessions
- `multi-agent-patterns` - Orchestration patterns

### Hooks

Automated guardrails that run during development:

| Hook | Trigger | Purpose |
|------|---------|---------|
| `pre-write-validate.sh` | Before Write/Edit | Blocks hardcoded credentials, magic test numbers in non-test files, non-evergreen naming |
| `pre-bash-validate.sh` | Before Bash | Blocks `--no-verify`, validates deploys, coverage warnings |
| `post-write.sh` | After Write/Edit | Auto-lints JavaScript files |
| `post-bash.sh` | After Bash | Deployment notifications |
| `subagent-log.sh` | After Subagent | Logs workflow activity |
| `session-checklist.sh` | On Stop | Warns about uncommitted changes and unpushed commits |
| `notify-ready.sh` | On Stop | Desktop notification when done |

> **⚠️ Known Limitation**: Due to a [Claude Code bug](https://github.com/anthropics/claude-code/issues/10225), plugin hooks may not execute automatically. To enable hooks, copy the configuration to your user settings:

<details>
<summary>Manual Hook Installation</summary>

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/plugins/cache/twilio-claude-plugin/twilio-claude-plugin/1.0.0/hooks/pre-write-validate.sh"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/plugins/cache/twilio-claude-plugin/twilio-claude-plugin/1.0.0/hooks/pre-bash-validate.sh"
          }
        ]
      }
    ]
  }
}
```

After adding, restart Claude Code with `Shift+Cmd+R` (macOS) or `Shift+Ctrl+R` (Linux).

</details>

## TDD Workflow

This plugin enforces Test-Driven Development:

1. **Red Phase** (`test-gen`): Write failing tests first
2. **Green Phase** (`dev`): Implement minimal code to pass
3. **Refactor**: Improve while keeping tests green

The `dev` agent verifies failing tests exist before implementing.

## Recommended Project Structure

```
your-project/
├── functions/           # Twilio serverless functions
│   ├── voice/           # Voice call handlers
│   ├── messaging/       # SMS/MMS handlers
│   └── helpers/         # Private shared utilities
├── assets/              # Static assets
├── __tests__/           # Test files
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── .env                 # Environment variables (never commit!)
└── package.json
```

## Environment Variables

Your project should define these in `.env`:

```bash
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_API_KEY=SKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_API_SECRET=your_api_secret
TWILIO_PHONE_NUMBER=+1234567890
```

## Usage Examples

**Build a voice IVR:**
```
I need a voice IVR that greets callers and routes them to sales or support
```

**Add SMS verification:**
```
Add phone verification to the signup flow using Twilio Verify
```

**Debug webhook issues:**
```
/twilio-logs
```

**Deploy to production:**
```
/deploy prod
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `npm test`
5. Submit a pull request

## License

MIT
