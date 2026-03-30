---
name: "voice-insights"
description: "Twilio development skill: voice-insights"
---

---
name: voice-insights
description: Voice Insights diagnostic guide. Use when investigating call quality, diagnosing "what happened on this call," auditing call patterns, or enabling Voice Insights Advanced Features.
---

# Voice Insights Diagnostic Skill

Actionable guide for diagnosing call quality, interpreting Voice Insights data, and managing Advanced Features. Load this skill when investigating call problems, running call audits, or enabling Insights APIs.

For per-metric threshold details, see [references/quality-thresholds.md](references/quality-thresholds.md).
For the full SIP code reference, see [references/sip-response-codes.md](references/sip-response-codes.md).
For SDK event taxonomy, see [references/sdk-events.md](references/sdk-events.md).

---

## 0. What Voice Insights Can and Cannot Tell You

**CAN detect:**
- Network quality degradation (jitter, packet loss, latency)
- Call setup failures (SIP response codes)
- Silence / missing audio streams (RTP-level)
- Abnormal call duration and post-dial delay
- Who disconnected the call (answered calls only)

**CANNOT detect:**
- **Echo** — acoustic feedback loops are in-stream; invisible to network sensors
- **Non-jitter noise** — static, hum, or device-generated noise
- **Speech content quality** — whether callee was the intended person, whether TTS sounded natural
- **Dropped calls that look normal** — most "drops" are indistinguishable from normal hangups at the signaling level

**Key limitations to remember:**
- Silence detection is **RTP-level** (missing/silent streams), not speech detection. Background noise prevents the `silence` tag even if nobody is talking.
- "Who Hung Up" requires an **answered call with SIP BYE**. Not available for unanswered, failed, canceled calls, or SDK calls where the browser closed before events transmitted.
- PDD thresholds are **per-destination-country percentile**, not fixed numbers. US standard <6s; South Africa commonly 10s.

---

## 1. When to Load This Skill

- Investigating call quality ("the call sounded choppy")
- Diagnosing call failures ("the call didn't connect")
- Auditing call patterns across the account
- Enabling or checking Voice Insights Advanced Features
- Conference diagnostics (quality attribution, region mismatch)
- ConversationRelay troubleshooting (cross-referencing Insights with CR logs)

---

## 2. Prerequisite Check

Before any diagnostic work, verify the account's Insights access level.

**Step 1:** `get_insights_settings` — check `advancedFeatures` and `voiceTrace` status.

**If Advanced Features is disabled:**
- API calls to events/metrics return **HTTP 401** (not 404, not empty data)
- Available WITHOUT Advanced Features: Console Dashboard + Call Summary page only. Basic Call Summary fields via API (`callState`, `callType`, `duration`, `tags`, `properties` including `last_sip_response_num`, `disconnected_by`, `direction`). Often sufficient for "did the call fail?"
- Available WITH Advanced Features: per-interval metrics, per-interval events, REST API access, Event Streams, Console Metrics tabs

**If recently enabled:**
- Data only exists from activation forward. Pre-activation calls have no interval metrics or events.
- May take 5-10 minutes to take effect.

**Billing:** Advanced Features is a per-minute add-on (rounds up to next minute). Only offer `update_insights_settings` with explicit billing acknowledgment from the user.

---

## 3. Single Call Diagnostic Workflow

The primary workflow for "what happened on this call?"

1. `get_call_summary(callSid)` — extract `callType`, `callState`, `tags`, `properties`, edge metrics
2. Interpret `callState`: `completed` | `fail` | `noanswer` | `busy` | `canceled` | `undialed`
3. Check `properties.last_sip_response_num` — see [Section 11: SIP codes](#11-sip-response-code-reference)
4. Check `properties.disconnected_by` — flag when an unexpected party disconnected
5. Check `tags[]` — interpret each tag against [Section 10: Quality thresholds](#10-quality-threshold-reference)
6. Determine relevant edge(s) via `callType` — see [Section 9: Edge selection](#9-edge-selection-decision-tree)
7. If quality tags present: `list_call_metrics(callSid, edge)` — compare against thresholds, look for degradation over time (sustained vs. spike)
8. If events needed: `list_call_events(callSid, edge)` — focus on WARNING/ERROR level events
9. Cross-reference: `validate_debugger(resourceSid: callSid)` for TwiML/webhook errors
10. Check TwiML execution logs via the Call Events API for request/response details
11. **Synthesize**: root cause + which party/edge was responsible + specific remediation

---

## 4. Conference Diagnostic Workflow

### Step 1: Conference Overview

`get_conference_summary(conferenceSid)` — extract `status`, `tags`, `detectedIssues`, `endReason`, region info.

### Step 2: Interpret Conference-Level Issues

- `detectedIssues.call_quality` > 0 — quality problems; drill into participant summaries
- `detectedIssues.region_configuration` > 0 — check `mixerRegion` vs `mixerRegionRequested`
- `detectedIssues.participant_behavior` > 0 — check participant event timelines

Conference tags to interpret: `quality_warnings`, `high_packet_loss`, `high_jitter`, `high_latency`, `low_mos`, `detected_silence`, `region_configuration_issues`, `invalid_requested_region`, `duplicate_identity`, `start_failure`, `participant_behavior_issues`

### Step 3: Per-Participant Deep Dive

`list_conference_participant_summaries(conferenceSid)` — for each participant examine:
- `metrics.inbound` and `metrics.outbound` separately (packet loss, jitter, latency, MOS)
- `events` timeline (mute/unmute/hold/unhold timestamps)
- `callType` + `callDirection` for context
- `isCoach` + `coachedParticipants` for coaching relationships
- `outboundQueueLength` + `outboundTimeInQueue` for queue-originated participants
- `properties` flags: `startConferenceOnEnter`, `endConferenceOnExit`, `enterMuted`

### Step 4: Quality Attribution

Identify which participant(s) caused conference-level quality issues:
- High `metrics.outbound.packet_loss_percentage` — that participant's upstream network is the problem
- High `metrics.inbound.packet_loss_percentage` — that participant's download path is degraded
- Compare MOS across participants — lowest MOS = worst experience
- If one participant has bad metrics and others are fine — isolated issue
- If all participants show similar degradation — conference mixer or region issue

### Step 5: Behavioral Analysis

- Rapid mute/unmute cycling in event timeline — may indicate UI issues
- Excessive hold time — participant experience issue
- `enterMuted: true` participant who never unmuted — may have been forgotten
- `endConferenceOnExit` participant leaving early — explains abrupt conference end

### Step 6: Cross-Reference

- For participants with `callStatus: "fail"` — drill into their `callSid` using the single call diagnostic workflow (Section 3)
- `validate_debugger(resourceSid: conferenceSid)` for conference-level errors
- Check if `endedBySid` matches an expected moderator or was an unexpected participant

**Conference timing caveats:**
- Conference must have 2+ participants to generate `startTime`
- Participant summaries only exist for participants who answered
- `summary_timeout` status means no terminal event received within 24 hours
- Summaries may take up to 30 minutes post-end; `processingState: "complete"` is the definitive signal

---

## 5. ConversationRelay Diagnostic Patterns

**Critical caveat:** ConversationRelay is a TwiML verb (`<Connect><ConversationRelay>`), NOT a call type. Voice Insights `callType` reflects the underlying transport:
- Inbound PSTN call — `carrier`
- Outbound API call to PSTN — `carrier`
- SIP endpoint — `sip`
- WebRTC client — `client`

**You cannot identify a CR call from Voice Insights alone.** To determine if a call used ConversationRelay:
- Cross-reference application logs (the WebSocket `setup` message contains the `callSid`)
- Check Sync documents if the CR handler writes call metadata there
- Check serverless function logs via `validate_call` with `serverlessServiceSid`
- Look at TwiML execution logs (Call Events API) for `<Connect>` verb usage

**Once confirmed as CR, the diagnostic approach depends on callType:**
- `carrier` CR call — investigate `carrier_edge` for PSTN quality; also check `sdk_edge` events for WebSocket-related issues on Twilio's media processing side
- `client` CR call — `sdk_edge` + `client_edge` are both relevant
- `sip` CR call — `sip_edge` for SIP signaling

**CR-specific quality patterns in Voice Insights:**
- **STT silence**: `silence` tag or `constant-audio-input-level` event — may indicate CR WebSocket is connected but audio is not flowing to STT
- **Short duration + completed state**: WebSocket may have disconnected (TTS error, LLM timeout) — the call "completed" normally from Twilio's perspective but the AI conversation was cut short
- **One-way audio**: Visible as silence or low audio_in metrics on one edge — check if both parties' audio is flowing through the media path
- **After Voice Insights diagnosis**: Use `validate_voice_ai_flow` for end-to-end CR validation (recording, transcript content, SMS delivery)

---

## 6. Discovery Workflow

Find problematic calls across the account:

| Query | Tool Call | Finds |
|-------|-----------|-------|
| Abnormal sessions | `list_call_summaries(abnormalSession: true)` | SIP response != 200 |
| Quality-tagged calls | `list_call_summaries(hasTag: true)` | Any quality/issue tags |
| Failed calls | `list_call_summaries(callState: "fail")` | Connection failures |
| Busy calls | `list_call_summaries(callState: "busy")` | Busy destinations |
| PSTN calls in window | `list_call_summaries(callType: "carrier", startTime, endTime)` | Carrier calls in timeframe |
| Conference quality | `list_conference_summaries(tags: "quality_warnings")` | Conferences with quality issues |
| Conference call quality | `list_conference_summaries(detectedIssues: "call_quality")` | Conferences with degraded participants |
| Conference region issues | `list_conference_summaries(tags: "region_configuration_issues")` | Region mismatches |

---

## 7. Aggregate Reporting

Account-level voice analytics (Reports v2 API):

- `get_account_voice_report(startTime, endTime)` — deliverability score, total volumes, ALOC, silent call %, AMD results
- `get_outbound_number_report(phoneNumber, startTime, endTime)` — per-number outbound patterns, STIR/SHAKEN attestation rates
- `get_inbound_number_report(phoneNumber, startTime, endTime)` — per-number inbound patterns

Useful for: systemic carrier issues, fraud detection, number reputation monitoring.

---

## 8. Annotation Workflow

After diagnosis, record findings on the call:

`update_call_annotation(callSid, {callScore: 1-5, qualityIssues: [...], comment: "...", incident: "TICKET-123"})`

- **Quality issues enum:** `low_volume`, `choppy_robotic`, `echo`, `dtmf`, `latency`, `owa` (one-way audio), `static_noise`
- **Connectivity issues enum:** `invalid_number`, `caller_id`, `dropped_call`, `number_reachability`
- **`answeredBy`:** `human` or `machine` (override AMD detection)
- **`spam`:** boolean flag

Annotations persist and are queryable via `list_call_summaries` filters.

**US1 region only** — other regions will return an error.

---

## 9. Edge Selection Decision Tree

```
callType from get_call_summary
  |
  +-- "carrier" --> Primary: carrier_edge
  |     Check: pdd_ms, last_sip_response_num, carrier latency
  |     Note: Carrier metrics are less controllable -- focus on detection, not remediation
  |
  +-- "client"  --> Primary: sdk_edge + client_edge
  |     Check: WebRTC stats, ICE connectivity, audio levels, MOS, RTT
  |     Note: Most actionable edge -- client-side network/device issues
  |
  +-- "sip"     --> Primary: sip_edge
  |     Check: SIP signaling, codec negotiation, registration status
  |     Note: Often configuration-related (wrong codecs, NAT issues)
  |
  +-- "trunking" --> Primary: carrier_edge + sip_edge
  |     Check: trunk config, SIP response, PDD
  |     Note: Carrier issues affect both edges
  |
  +-- "whatsapp" --> Primary: carrier_edge
        Check: Similar to carrier but WhatsApp-specific delivery
```

**Sampling rate differences by edge:**
- **SDK metrics**: sampled every 1 second (high temporal resolution)
- **Carrier/SIP metrics**: cumulative 10-second intervals, sampled every 10 seconds

SDK has 10x the temporal resolution. This matters when correlating events across edges.

---

## 10. Quality Threshold Reference

**MOS scale is 1.0 to 4.6** (not 5.0). Computed once per second. Monotonically decreasing with jitter and packet loss.

**SDK warnings are MORE sensitive than Insights tagging thresholds** — SDK fires quality warnings at lower thresholds for early detection. Example: SDK `high-packet-loss` fires at 1% in 3/5 1-second samples; the Insights tag fires at >5% cumulative.

| Metric | Good | Warning | Critical | Edge | Notes |
|--------|------|---------|----------|------|-------|
| Jitter avg | < 5ms | 5-15ms | > 15ms | Any | ITU-T based |
| Jitter max | < 30ms | 30-50ms | > 50ms | Any | ITU-T based |
| Packet Loss | < 1% | 1-5% | > 5% | Any | >1% causes choppiness |
| MOS | > 4.0 | 3.5-4.0 | < 3.5 | sdk_edge | Range: 1.0-4.6 |
| RTT | < 200ms | 200-400ms | > 400ms | sdk_edge | Round-trip |
| PDD | varies | > p95 | >> p95 | carrier | Per-country percentile |
| Latency | < 150ms | 150-300ms | > 300ms | Any | One-way RTP traversal |

**Conference per-participant thresholds:**

| Metric | Warning | Critical | Notes |
|--------|---------|----------|-------|
| Participant PL | > 3% | > 5% | Check inbound vs outbound separately |
| Participant jitter | avg > 40ms | max > 100ms | |
| Participant latency | > 150ms | > 300ms | High latency + conference = jitter buffer swelling |
| Participant MOS | < 3.5 | < 3.0 | Range 1.0-4.6 |

Full per-metric, per-edge detail in [references/quality-thresholds.md](references/quality-thresholds.md).

---

## 11. SIP Response Code Reference

| Code | Meaning | Typical Cause | Action |
|------|---------|---------------|--------|
| 200 | OK | Success | None needed |
| 400 | Bad Request | Malformed SIP | Check TwiML, number format |
| 403 | Forbidden | Auth failure | Check account status, IP ACLs |
| 404 | Not Found | Invalid destination | Check number, routing config |
| 408 | Request Timeout | No response | Network issue, carrier timeout |
| 480 | Temporarily Unavailable | Device off/unreachable | Retry later, check device |
| 484 | Address Incomplete | Partial number | Check E.164 format |
| 486 | Busy Here | Callee on another call | Retry, offer voicemail |
| 487 | Request Terminated | Caller hung up before answer | Normal if short ring time |
| 488 | Not Acceptable Here | Codec mismatch | Check SIP trunk codec config |
| 491 | Request Pending | Collision | Automatic retry usually resolves |
| 500 | Server Internal Error | Twilio/carrier failure | Retry, check status page |
| 502 | Bad Gateway | Upstream failure | Carrier issue |
| 503 | Service Unavailable | Overloaded | Rate limit, retry with backoff |
| 504 | Server Timeout | Gateway timeout | Carrier latency issue |
| 600 | Busy Everywhere | All endpoints busy | All devices occupied |
| 603 | Decline | Call explicitly rejected | Callee rejected the call |
| 604 | Does Not Exist | Number doesn't exist | Verify destination number |
| 606 | Not Acceptable | Media negotiation failed | Codec/capability mismatch |

**Range-based classification:** 2xx = success, 3xx = redirect/config, 4xx = client/caller error, 5xx = server/carrier error, 6xx = global failure.

**SIP error actionability:**
- **Carrier-origin SIP errors** are not directly actionable — contact Twilio Support if impacting users.
- **SIP Interface/trunking errors** — compare local logs/pcaps with Twilio public pcap.
- **SDK SIP errors** — enable debug logging and reproduce.

Full reference with all ranges in [references/sip-response-codes.md](references/sip-response-codes.md).

---

## 12. Common Diagnosis Patterns

| Pattern | Insights Signature | Root Cause | Remediation |
|---------|-------------------|------------|-------------|
| One-way audio | `silence` tag, normal duration, one edge has metrics but other shows low/zero audio. Silence detection is RTP-level; background noise masks the tag even with no speech. | NAT traversal failure, firewall blocking RTP, codec mismatch | Check ICE candidates (client), verify STUN/TURN config, check firewall rules |
| Call drops mid-conversation | Short duration, no error tags, `disconnected_by` = unexpected party | Network instability, carrier timeout, WebSocket disconnect (CR) | Check metric time series for degradation before drop, verify keepalive config |
| Poor/choppy audio | `high_jitter` + `high_packet_loss` tags, sustained metric degradation | Bad network path, congested link, WiFi interference | Identify affected edge; sdk_edge = client network; carrier_edge = carrier issue |
| Failed connection | `callState: "fail"`, SIP 4xx/5xx, carrier_edge errors | Invalid number, carrier rejection, auth failure | SIP code lookup (Section 11) for specific action per code |
| High post-dial delay | `high_pdd` tag, `pdd_ms` above country p95 | Carrier routing inefficiency, international path | Compare to baseline, may need carrier escalation |
| Echo/feedback | **Voice Insights CANNOT detect echo.** Only identifiable via user feedback (SDK feedback API or call annotation). High latency may correlate with perceived echo. | Speaker volume / mic gain causing acoustic feedback loop | Reduce speaker volume, enable AEC on device, reduce network latency if >150ms one-way |
| Conference quality degrades over time | `quality_warnings` tag, participant metrics show degradation after N minutes | Media mixer overload, participant count exceeds capacity | Check `maxConcurrentParticipants`, consider region optimization |
| Conference region mismatch | `region_configuration_issues` tag, `mixerRegion != mixerRegionRequested` | Requested region unavailable or misconfigured | Verify `<Dial region>` parameter, check region availability |
| Participant isolation | One participant has bad metrics, others fine | That participant's network is the problem | Compare inbound vs outbound loss on that participant to determine direction |
| Conference silence | `detected_silence` tag, all participants low MOS | No audio flowing through mixer | Check if all participants muted, verify audio tracks publishing |

---

## Related Resources

- [Voice Development Skill](/skills/voice/SKILL.md) - Use case ladder, decision frameworks, TwiML patterns
- [Deep Validation Skill](/skills/deep-validation.md) - Enhanced `checkVoiceInsights` and `checkConferenceInsights` with threshold comparison and tag interpretation
- [Validation Tools Source](/twilio/src/validation/deep-validator.ts) - `validateCall()` and `validateConference()` implementation
- [ConversationRelay CLAUDE.md](/CLAUDE.md) - CR protocol, streaming, LLM integration, troubleshooting
- [Event Streams Skill](/skills/event-streams/SKILL.md) - Push-based delivery of Voice Insights events (call-summary, call-event, call-metrics) via sinks
- [Voice MCP Tools](/twilio/src/tools/voice.ts) - 41 tools including:
  - Insights search: `list_call_summaries`, `list_conference_summaries`
  - Insights data: `get_call_summary`, `list_call_metrics`, `list_call_events`
  - Conference Insights: `get_conference_summary`, `list_conference_participant_summaries`, `get_conference_participant_summary`
  - Annotation: `get_call_annotation`, `update_call_annotation`
  - Settings: `get_insights_settings`, `update_insights_settings`
  - Reports v2: `get_account_voice_report`, `get_inbound_number_report`, `get_outbound_number_report`
- [Branded Calling Skill](/skills/branded-calling/SKILL.md) — SHAKEN/STIR attestation, Voice Integrity, Reports API for branded calling ROI measurement
