---
name: proxy
description: Anonymous number masking with Twilio Proxy for rideshare, marketplace, and healthcare use cases.
---

# Proxy Skill

Anonymous number masking with Twilio Proxy for rideshare, marketplace, and healthcare use cases.

## What is Twilio Proxy?

Proxy enables anonymous communication between two parties (e.g., rider/driver, buyer/seller) through masked phone numbers. Neither party sees the other's real number.

## Session Flow

```
1. Create a proxy session
2. Add participant A (rider)
3. Add participant B (driver)
4. Twilio assigns proxy numbers to each participant
5. A calls/texts B's proxy number → routed to B's real number
6. B calls/texts A's proxy number → routed to A's real number
7. Close session when done
```

## Intercept Callback

The intercept callback fires before each interaction is connected:
- Return **200** to allow the interaction
- Return **403** to block the interaction
- Use for logging, rate limiting, or business rules

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `TWILIO_PROXY_SERVICE_SID` | Yes | Proxy Service SID (starts with KS) |

## Session Modes

| Mode | Description |
|------|-------------|
| `voice-and-message` | Both calls and SMS (default) |
| `voice-only` | Calls only |
| `message-only` | SMS only |
