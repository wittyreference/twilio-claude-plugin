# Twilio Claude Plugin (v1.3.0)

A Claude Code plugin that brings Twilio CPaaS expertise to any project. Provides specialized agents, commands, and skills for building voice, messaging, and real-time communication applications with Twilio.

## Prerequisites

The plugin requires these tools to be installed:

| Requirement | Version | Purpose |
|-------------|---------|---------|
| Twilio Account | — | [Sign up free](https://www.twilio.com/try-twilio) — need Account SID + Auth Token |
| Node.js | 20+ | Runtime for Twilio Functions |
| npm | (bundled with Node) | Package management |
| jq | Latest | JSON processing (required by safety hooks) |
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

## Quick Start

```bash
# 1. Install the plugin
claude plugin add github:wittyreference/twilio-claude-plugin

# 2. Create .env in your project root
cat > .env << 'EOF'
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_PHONE_NUMBER=+1234567890
EOF

# 3. Start Claude Code and verify setup
claude
# Then run: /preflight
```

Once verified, try prompts like:
- "Send a test SMS to +15551234567"
- "Build a voice IVR that routes callers to sales or support"
- "Add phone verification to the signup flow using Twilio Verify"

Run `/help-twilio` to discover all available skills and capabilities.

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

### MCP Tools (310 Twilio API Tools)

The plugin includes an MCP server that gives Claude direct access to 310 Twilio API tools — messaging, voice, conferences, recordings, TaskRouter, Sync, payments, phone numbers, Studio flows, and more. Tools are automatically available when the plugin is enabled and environment variables are set.

**Capabilities include:**
- Send SMS/MMS, manage messaging services, content templates
- Make and manage calls, conferences, recordings, media streams
- TaskRouter: create tasks, list workers, check queue statistics
- Sync: create/read/update documents, lists, maps
- Phone numbers: search, purchase, configure webhooks
- Verify: send and check OTP codes
- Studio: trigger flows, inspect executions
- Voice Intelligence: transcriptions, operator analysis
- And many more (video rooms, proxy, SIP trunking, regulatory bundles, etc.)

**Example prompts:**
- "Send a test SMS to +15551234567"
- "List my TaskRouter workers"
- "Check queue statistics for my support queue"
- "Search for available phone numbers in area code 415"

The MCP server requires `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, and `TWILIO_PHONE_NUMBER` at minimum. See [Environment Variables](#environment-variables) for the full list.

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
| `/learn [action]` | Interactive learning exercises on autonomous work (generation effect) | — |
| `/check-updates` | Check for newer plugin versions on GitHub | — |

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
| **Orchestrate** | Coordinates multi-agent development workflows |

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
- `pay` - PCI-compliant payments with `<Pay>` verb
- `proxy` - Number masking and anonymous communication
- `phone-numbers` - Phone number management and configuration
- `sip-byoc` - SIP trunking and Bring Your Own Carrier
- `payments` - Payment processing patterns and flows
- `compliance-regulatory` - Regulatory bundles and compliance

**Reference:**
- `twilio-cli` - Comprehensive CLI command reference
- `twilio-invariants` - Proven gotchas that cause silent failures (credential formats, protocol fields, deployment traps)
- `voice-use-case-map` - Definitive product mapping for 10 voice use cases (notifications through AI transcription)
- `deep-validation` - Validation patterns beyond HTTP 200 (status polling, debugger checks, Voice Insights)
- `tdd-workflow` - TDD Red/Green/Refactor patterns for Twilio projects
- `brainstorm` - Ideation template for Twilio app concepts with validation mapping
- `tool-boundaries` - Golden Rules and Risk Tiers for MCP vs CLI vs Functions decisions
- `operational-gotchas` - Hard-won debugging insights across testing, deployment, voice routing, auth, and MCP
- `workflows` - Development pipeline patterns (new-feature, bug-fix, refactor, security-audit)

**Context Engineering:**
- `context-engineering` - Unified context management: compression ratios, budgets, loading strategies
- `memory-systems` - State tracking across sessions
- `multi-agent-patterns` - Orchestration patterns

**Additional:**
- `agent-testing` - Agent-to-agent testing patterns for ConversationRelay
- `getting-started` - Quick-start guide for new Twilio projects
- `context-hub` - External API reference loader
- `env-doctor` - Environment conflict detection and resolution
- `video` - Video rooms, recordings, and compositions
- `video-patterns` - Video application patterns and best practices

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
| `session-start.sh` | On session start | Environment checks, stale session detection |
| `subagent-log.sh` | After Subagent | Logs subagent workflow activity |
| `notify-ready.sh` | On Stop | Desktop notification when done |

> **⚠️ Known Limitation**: Due to a [Claude Code bug](https://github.com/anthropics/claude-code/issues/10225), plugin hooks may not execute automatically. To enable hooks, copy the configuration to your user settings:

<details>
<summary>Manual Hook Installation</summary>

First, find your plugin cache path:

```bash
# The version directory changes with each plugin update
ls ~/.claude/plugins/cache/twilio-claude-plugin/twilio-claude-plugin/
```

Then add to `~/.claude/settings.json` (replace `VERSION` with the version from above):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/plugins/cache/twilio-claude-plugin/twilio-claude-plugin/VERSION/hooks/pre-write-validate.sh"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/plugins/cache/twilio-claude-plugin/twilio-claude-plugin/VERSION/hooks/pre-bash-validate.sh"
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

**Required** (for MCP tools and CLI operations):

```bash
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_PHONE_NUMBER=+1234567890
```

**Optional** (for specific features):

```bash
# API keys (for CLI operations)
TWILIO_API_KEY=SKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_API_SECRET=your_api_secret

# MCP tool features
TWILIO_VERIFY_SERVICE_SID=VAxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx    # Verify OTP tools
TWILIO_SYNC_SERVICE_SID=ISxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx      # Sync Documents/Lists/Maps
TWILIO_TASKROUTER_WORKSPACE_SID=WSxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  # TaskRouter tools
TWILIO_MESSAGING_SERVICE_SID=MGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx # Messaging Services tools
TEST_PHONE_NUMBER=+1234567890                                    # Recipient for test messages/calls
```

### Credential Resolution Priority

The MCP server resolves credentials in this order (highest priority first):

1. **Shell environment** — Variables from `.zshrc`, `.bashrc`, or `export` statements
2. **direnv** — `.envrc` file if `direnv` is configured
3. **`.env` file** — Loaded by the MCP server at startup
4. **Twilio CLI profile** — From `twilio login` (CLI commands only, not MCP tools)

> **If you already have `TWILIO_*` env vars in your shell** (from `.zshrc`, another project, or Twilio CLI), they will silently override your `.env` values and cause auth failures. The Twilio SDK also auto-reads `TWILIO_REGION` and `TWILIO_EDGE`, which can silently route API calls to the wrong region.

**Diagnose conflicts:**

```bash
# Run the environment doctor (included with this plugin)
./scripts/env-doctor.sh
```

**Prevent conflicts with direnv:**

The plugin ships an `.envrc` template that unsets all inherited Twilio vars before loading your `.env`:

```bash
# Copy the template to your project root
cp scripts/envrc.template .envrc

# Install direnv and allow
brew install direnv
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
direnv allow
```

## Interactive Setup

For guided provisioning of Twilio resources (phone numbers, Verify service, Sync service, TaskRouter workspace, Messaging Service):

```bash
node scripts/setup.js
```

The script walks you through each resource, creates what's needed, and updates your `.env` automatically.

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
