# Twilio Claude Plugin

A Claude Code plugin that brings Twilio CPaaS expertise to any project. Provides specialized agents, commands, and skills for building voice, messaging, and real-time communication applications with Twilio.

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

**Context Engineering:**
- `context-fundamentals` - Context management principles
- `context-compression` - TwiML and payload compression
- `memory-systems` - State tracking across sessions
- `multi-agent-patterns` - Orchestration patterns

### Hooks

Automated guardrails that run during development:

| Hook | Trigger | Purpose |
|------|---------|---------|
| `pre-write-validate.sh` | Before Write/Edit | Blocks hardcoded credentials |
| `pre-bash-validate.sh` | Before Bash | Blocks `--no-verify`, validates deploys |
| `post-write.sh` | After Write/Edit | Auto-lints JavaScript files |
| `post-bash.sh` | After Bash | Deployment notifications |
| `subagent-log.sh` | After Subagent | Logs workflow activity |
| `notify-ready.sh` | On Stop | Desktop notification when done |

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
