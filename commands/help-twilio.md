---
description: Find the right Twilio skill for your use case. Use when unsure which skill to invoke, building a new feature, or exploring available capabilities.
---

# Twilio Skill Navigator

Help the user find the right skill(s) for their use case.

## How to Use

If the user provided a use case or question, match it to the relevant skills below and invoke them. If no arguments, show the full index.

## Skill Index

### Voice & Calling
| Skill | Use When |
|-------|----------|
| `/voice` | Building IVR, call routing, TwiML flows, outbound calls, AMD, limits |
| `/voice-use-case-map` | Choosing between Twilio voice products (Programmable Voice, Elastic SIP, Voice AI) |
| `/voice-sdks` | Browser softphones, mobile calling apps, AccessTokens, TwiML Apps, edge locations |
| `/android-sdk` | Android native Voice + Video — Gradle, FCM push, ConnectionService, permissions, emulator testing |
| `/voice-trust` | Spam/blocked calls, answer rates, SHAKEN/STIR, StirVerstat, CallToken, Branded Calling, Voice Integrity, CNAM |
| `/whatsapp-business-calling` | Voice calls over WhatsApp endpoints, `<Dial><WhatsApp>` |
| `/media-streams` | Real-time audio processing, transcription, bidirectional streaming |
| `/recordings` | Call recording methods, channel assignment, pause/resume, Voice Intelligence transcription |
| `/sip` | Programmable SIP — SIP Domains, registration, custom headers, auth models, `<Dial><Sip>` |
| `/sip-byoc` | SIP trunking, Bring Your Own Carrier, Elastic SIP Trunking |
| `/elastic-sip-trunking` | Deep Elastic SIP Trunking — trunk lifecycle, routing, recording, security, auth, diagnostics |

### AI Agents & Middleware
| Skill | Use When |
|-------|----------|
| `/agent-connect` | Connecting LLM apps to Twilio voice/SMS via TAC middleware, Customer Memory integration |
| `/conversationrelay` | Building voice AI agents with ConversationRelay — TwiML attributes, WebSocket protocol, STT/TTS providers, ngrok setup, CI integration |
| `/synthetic-calls` | Generating bulk synthetic calls with customer personas, stress-testing voice AI, building demo data at scale |
| `/coval` | Coval voice AI evaluation — benchmarking with simulated calls, LLM-judge metrics, personas with noise/interruptions, production call monitoring, A/B testing, scheduled regression |

### Messaging & Email
| Skill | Use When |
|-------|----------|
| `/voice` (see `functions/messaging/CLAUDE.md`) | SMS/MMS — no dedicated skill; see function docs |
| `/compliance-regulatory` | Campaign management, A2P 10DLC, messaging compliance |
| `/sendgrid-email` | Sending transactional/bulk email, dynamic templates, event webhooks, Inbound Parse, suppressions |

### Identity & Security
| Skill | Use When |
|-------|----------|
| `/iam` | Authentication methods, API keys (Standard/Main/Restricted), Access Tokens, auth token rotation, subaccounts, test credentials, PKCV |
| `/verify` | Phone/email OTP verification, fraud prevention |
| `/lookup` | Phone number intelligence — line type, carrier, CNAM, SIM swap, SMS pumping risk, identity match |
| `/branded-calling` | Branded Calling (Basic/Enhanced), SHAKEN/STIR attestation, Voice Integrity spam remediation, CNAM, improving answer rates |
| `/compliance-regulatory` | GDPR, TCPA, PCI, HIPAA, A2P 10DLC compliance |

### Data & Orchestration
| Skill | Use When |
|-------|----------|
| `/segment` | Segment Connections — sources, destinations, custom Functions, Reverse ETL, Segment Spec, connection modes, data pipeline design |
| `/sync` | Real-time state sync — Documents, Lists, Maps, Streams, TTL lifecycle, data type selection, MCP tool gaps, error codes |
| `/customer-memory` | Customer Memory (Memora) — profiles, traits, observations, Recall, identity resolution, AI-powered personalization |
| `/conversations-v2` | Multi-channel conversation tracking (Maestro), omnichannel history, participant types, v1 migration |
| `/conversational-intelligence` | Real-time/post-call conversation analysis, Language Operators, sentiment, agent assist, cross-channel analytics (v3 API) |
| `/sierra` | Unified Sierra stack — Conversations v2 + Customer Memory + Intelligence v3 pipeline, end-to-end setup, cross-product integration patterns and gotchas |
| `/taskrouter` | Skills-based routing — workflows, queues, expressions, reservations, assignment callbacks, 30 MCP tools |
| `/event-streams` | Streaming Twilio events to webhooks/Kinesis/Segment — sinks, subscriptions, CloudEvents, deduplication |
| `/event-streams` | Status webhooks, delivery receipts, event streaming |

### Payments & Privacy
| Skill | Use When |
|-------|----------|
| `/payments` | Choosing between Pay, Pay Connectors, and custom payment flows |
| `/payments` | PCI-compliant payment collection during voice calls |
| `/proxy` | Number masking (rider/driver, buyer/seller) — sessions, pools, webhooks, geo-matching. Public Beta. |

### Video
| Skill | Use When |
|-------|----------|
| `/video` | Video rooms, participants, tracks, use case selection |
| `/video` | Compositions, recordings, network optimization, SDK integration |
| `/ios-sdk` | Native iOS apps — Voice SDK CallKit/PushKit, Video SDK tracks/rooms, permissions, background modes |

### Infrastructure & Tools
| Skill | Use When |
|-------|----------|
| `/phone-numbers` | Searching, purchasing, configuring webhooks, releasing phone numbers |
| `/twilio-cli` | CLI vs MCP vs Console decision guide — profiles, deployment, CLI-only operations, serverless toolkit |
| `/twilio-cli` | Deciding between MCP tools, CLI, and Serverless Functions (see also `.claude/references/tool-boundaries.md`) |
| See `.claude/rules/*-invariants.md` | Architectural rules that prevent subtle bugs (auto-loaded by hooks) |
| `/env-doctor` | Environment validation, credential troubleshooting |
| `/deep-validation` | Validating beyond HTTP 200 — Voice Insights, debugger alerts, status checks |
| See `.claude/references/operational-gotchas.md` | Common debugging pitfalls, cross-cutting failure patterns |

### Development Methodology
| Skill | Use When |
|-------|----------|
| See `QUICKSTART.md` | First time using the toolkit, bootstrapping a new Twilio project |
| `/tdd-workflow` | Test-driven development cycle, red/green/refactor |
| `/multi-agent-patterns` | Orchestrating multiple Claude agents, parallel workflows |
| `/context-engineering` | Managing context window, compression techniques |
| `/context-hub` | Fetching external API docs (OpenAI, Stripe, SendGrid) |
| `/memory-systems` | Session memory, project state, cross-session persistence |
| See `.claude/references/brainstorm.md` | Feature ideation, design space exploration |
| See `.claude/references/workflow-patterns.md` | Pipeline overview (architect → spec → test-gen → dev → review → docs) |

## Use Case Quick Reference

| I want to... | Start with |
|--------------|------------|
| Build an IVR | `/voice` then `/voice-use-case-map` |
| Add phone verification | `/verify` |
| Check phone number type/carrier/fraud | `/lookup` |
| Send SMS/MMS | `/messaging` |
| Send transactional email | `/sendgrid-email` |
| Build a voice AI agent | `/conversationrelay` or `/agent-connect` |
| Connect LLM to Twilio with customer memory | `/agent-connect` then `/customer-memory` |
| Store customer context across sessions | `/customer-memory` |
| Process real-time audio | `/media-streams` |
| Handle payments over the phone | `/pay` |
| Build a contact center | `/taskrouter` then `/voice` |
| Add video to my app | `/video` then `/ios-sdk` or `/android-sdk` for native |
| Build a native iOS calling app | `/ios-sdk` then `/voice-sdks` |
| Build native Android calling/video app | `/android-sdk` |
| Mask phone numbers | `/proxy` |
| Sync real-time state | `/sync` |
| Connect my SIP infrastructure | `/sip` or `/elastic-sip-trunking` |
| Set up A2P 10DLC | `/messaging-services` then `/compliance-regulatory` |
| Analyze conversations with AI (sentiment, summary, agent assist) | `/conversational-intelligence` |
| Stream events to my analytics pipeline | `/event-streams` |
| Debug a failing call | `/deep-validation` then `/operational-gotchas` |
| Understand what MCP tools to use | `/tool-boundaries` |
| Build a data pipeline with Segment | `/segment` |
| Write custom Segment Functions | `/segment` (see Functions reference) |
| Start a new Twilio project | `/getting-started` |

## Arguments

<user_request>
$ARGUMENTS
</user_request>

If the user described a use case, identify the 1-3 most relevant skills and invoke them in sequence. If the user said a specific skill name, invoke that skill directly.
