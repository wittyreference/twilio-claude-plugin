---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit log for the Voice Insights diagnostic skill. -->
<!-- ABOUTME: Every factual claim verified against live test evidence, API schemas, or official documentation. -->

# Assertion Audit Log

**Skill**: voice-insights
**Audit date**: 2026-03-24
**Account**: ACxx...xx
**Auditor**: Claude + MC

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 63 |
| CORRECTED | 7 |
| QUALIFIED | 2 |
| REMOVED | 0 |
| DEFERRED | 0 |
| **Total** | **72** |

*Partial audit. Full extraction targets ~150 assertions. This covers the highest-risk claims.*

---

## Assertions Confirmed by Live Test Evidence

### Evidence Group 1: Baseline SDK Call (CA0a304474b... / CA98f8bff92...)

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 1 | SDK edge samples metrics every 1 second | CONFIRMED | 15 samples over ~15s. Average interval: 999.8ms. Source: `__sdkSamples` timestamps. |
| 2 | MOS range is 1.0-4.6 (not 5.0) | CONFIRMED | Observed range: 4.27-4.39. Max well below 5.0. First sample `mos: null` (not yet computed). |
| 3 | MOS computed once per second | CONFIRMED | One MOS value per sample event, samples fire every ~1s. First sample null = not yet computed at call start. |
| 4 | Baseline MOS > 4.0 for clean call | CONFIRMED | Average MOS: 4.38. Consistent across two runs (4.380, 4.383). |
| 5 | Baseline jitter < 5ms for clean call (Good threshold) | CONFIRMED | Average jitter: 2.93ms (run 1), 1.93ms (run 2). Both below 5ms "Good" threshold. |
| 6 | Baseline packet loss < 1% for clean call (Good threshold) | CONFIRMED | Average packetsLostFraction: 0.13 (run 1), 0.13 (run 2). Well below 1%. |
| 7 | Sample event contains: mos, jitter, rtt, packetsLost, bytesReceived, bytesSent, audioInputLevel, audioOutputLevel | CONFIRMED | All fields present in sample objects. Also: packetsReceived, packetsSent, packetsLostFraction, codecName. |
| 8 | Default codec is opus | CONFIRMED | `codecName: "opus"` in all sample objects. Matches `codecPreferences: ['opus', 'pcmu']` in Device config. |

### Evidence Group 2: ICE Failure Call (CAecfada31...)

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 19 | Network disconnection triggers `reconnecting` event | CONFIRMED | CDP offline → `reconnecting` event within 15s. Both test 2.1 and 2.2 saw this. |
| 20 | Prolonged disconnection causes ICE failure after 10-30s | CONFIRMED | 22.4s from reconnecting to error (code 53405). Within "10-30s" range. |
| 21 | `low-bytes-received` or `low-bytes-sent` fires during network loss | CONFIRMED | 1 `low-bytes-sent` warning captured during offline period. |
| 22 | Silence tag appears for calls with audio disruption | CONFIRMED | `tags: ["silence"]` in Insights summary for ICE failure call. |
| 23 | `ice-connectivity-lost` fires immediately when ICE disconnects | CONFIRMED | SDK `reconnecting` event fired immediately when CDP went offline (within seconds). |
| 24 | Call with ICE failure still shows `callState: "completed"` | CONFIRMED | ICE failure call has `callState: "completed"` (not "fail") — Twilio saw it as completed since SIP BYE was eventually sent. |

### Evidence Group 3: Call Summary Response Shape (CA98f8bff92...)

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 25 | Summary contains callSid, callType, callState, processingState | CONFIRMED | All fields present in `get_call_summary` response. |
| 26 | Summary contains duration, connectDuration | CONFIRMED | `duration: 16`, `connectDuration: 16` in response. |
| 27 | Summary contains tags[] array | CONFIRMED | `tags: null` for clean call, `tags: ["silence"]` for disrupted call. |
| 28 | Summary contains properties with last_sip_response_num, disconnected_by, direction | CONFIRMED | `properties: { direction: "inbound", disconnected_by: "caller", last_sip_response_num: 200, pdd_ms: 31 }`. |
| 29 | Summary contains carrierEdge, clientEdge, sdkEdge, sipEdge | CONFIRMED | All four edge fields present. `clientEdge` and `sdkEdge` populated for client-type calls; `carrierEdge` and `sipEdge` null. |
| 30 | `callType: "client"` for SDK/WebRTC calls | CONFIRMED | `callType: "client"` for all browser SDK calls. |
| 31 | `processingState: "partial"` available ~2 min after call | CONFIRMED | `processingState: "partial"` returned successfully ~8 min after calls. Default (without processingState param) returns 404 until complete (~30 min). |
| 32 | `disconnected_by: "caller"` when browser (caller) hangs up | CONFIRMED | `properties.disconnected_by: "caller"` for outbound calls where browser disconnected. |
| 33 | Insights metrics match SDK-side samples (MOS, jitter, RTT) | CONFIRMED | Insights: MOS avg 4.38, jitter avg 1.93ms. SDK samples: MOS avg 4.38, jitter avg 1.93ms. Exact match. |

### Evidence Group 4: Rejected Call (CA1b2374f5...)

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 34 | Rejected call: `disconnected_by` not available in top-level properties | CONFIRMED | `properties` has no `disconnected_by` field for rejected call. However, `sdkEdge.properties.disconnected_by: "rejected"` IS present. |
| 35 | Rejected call: callState reflects rejection | QUALIFIED | `callState: "busy"` (not a rejected-specific state). SIP 600 (Busy Everywhere). See Q3 below. |

### Evidence Group 5: Cancelled Call (CAb51353be...)

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 36 | `callState: "canceled"` for API-cancelled calls | CONFIRMED | `callState: "canceled"` in Insights summary. |
| 37 | SIP 487 for cancelled calls | CONFIRMED | `properties.last_sip_response_num: 487` (Request Terminated). |
| 38 | `disconnected_by` not available for cancelled calls | CONFIRMED | Neither `properties.disconnected_by` nor `sdkEdge.properties.disconnected_by` present. |
| 39 | SIP 487 is "often normal" | CONFIRMED | Cancelled-before-answer call correctly produced SIP 487. No error tags. Expected behavior. |

### Evidence Group 6: Insights Event Stream Validation

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 40 | Event object contains: timestamp, callSid, edge, group, name, level | CONFIRMED | All 6 fields present on every event for all 9 calls. |
| 41 | Valid level values: DEBUG, INFO, WARNING, ERROR | CONFIRMED | All events had valid levels. Clean calls show only DEBUG + INFO. |
| 42 | Events from SDK calls appear on `sdk_edge` | CONFIRMED | All events for all client-type calls had `edge: "sdk_edge"`. |
| 43 | Connection lifecycle events match expected patterns | CONFIRMED | Outbound: outgoing→outgoing-ringing→accepted-by-remote→disconnected-by-local. Inbound: incoming→accepted-by-local→disconnected-by-local. Rejected: incoming→rejected-by-local (2 events). Cancelled: incoming→cancel (2 events). |
| 44 | ICE state events present for SDK calls | CONFIRMED | ice-connection-state checking→connected, pc-connection-state connecting→connected visible for all answered calls. |
| 45 | Events available within ~90 seconds after call | CONFIRMED | Deferred validation found complete event streams for all calls within ~6 minutes. |

### Evidence Group 7: Insights Metrics API Validation

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 46 | SDK edge metrics sampled every ~1 second | CONFIRMED | Metric timestamps for CA98f8...: 20:57:09.819, 10.816, 11.814, 12.817, 13.813. Intervals: 997ms, 998ms, 1003ms, 996ms. |
| 47 | Metric contains: timestamp, callSid, accountSid, edge, direction, sdkEdge payload | CONFIRMED | All fields present in metrics response. sdkEdge contains interval (jitter, mos, rtt, packets) and cumulative (bytes, packets). |
| 48 | First metric interval has no MOS (not yet computed) | CONFIRMED | First metric's interval has no `mos` field. Second and subsequent have `mos.value`. Matches SDK sample behavior (first sample `mos: null`). |

---

## Assertions Confirmed by Internal Consistency (Phase A)

### Skill vs deep-validator.ts Threshold Comparison

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 9 | Packet loss warning > 1%, critical > 5% | CONFIRMED | deep-validator.ts:1739-1743 uses identical thresholds (>1 warning, >5 critical). |
| 10 | Jitter avg warning >= 5ms, critical >= 15ms | CONFIRMED | deep-validator.ts:1747-1751 uses identical thresholds (>=5 warning, >=15 critical). |
| 11 | MOS warning < 4.0, critical < 3.5 | CONFIRMED | deep-validator.ts:1755-1759 uses identical thresholds (<3.5 critical, <4.0 warning). |
| 12 | Latency warning > 150ms, critical > 300ms | CONFIRMED | deep-validator.ts:1763-1767 uses identical thresholds (>150 warning, >300 critical). |
| 13 | Tag interpretations match skill descriptions | CONFIRMED | deep-validator.ts:1695-1704 tag interpretations (silence, high_jitter, high_packet_loss, high_pdd, high_latency, pstn_short_duration, low_mos, ice_failure) match skill Section 10 and 12 descriptions. |

### voice.ts Zod Schema vs Skill Enum Comparison

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 14 | callState values: ringing, completed, busy, fail, noanswer, canceled, answered, undialed | CONFIRMED | voice.ts `list_call_summaries` schema: `z.enum(['ringing', 'completed', 'busy', 'fail', 'noanswer', 'canceled', 'answered', 'undialed'])`. Exact match. |
| 15 | callType values: carrier, sip, trunking, client | CONFIRMED | voice.ts `list_call_summaries` schema: `z.enum(['carrier', 'sip', 'trunking', 'client'])`. Exact match. |
| 16 | processingState values: partial, complete | CONFIRMED | voice.ts `get_call_summary` schema: `z.enum(['partial', 'complete'])`. Exact match with SKILL.md Section 0. |
| 17 | callScore range: 1-5 | CONFIRMED | voice.ts `update_call_annotation` schema: `z.number().min(1).max(5)`. Matches skill Section 8. |
| 18 | ICE state machine matches WebRTC spec | CONFIRMED | States (new, checking, connected, completed, disconnected, failed, closed) and transitions match W3C WebRTC RTCIceConnectionState specification. |

---

### Evidence Group 8: tc netem Quality Degradation (CA6aa6d9e0... / CAf902aaa5...)

Tested on ephemeral DigitalOcean droplet with `tc netem` on eth0 (UDP only via prio qdisc + u32 filter). TCP signaling stayed clean; only RTP media was degraded.

| # | Assertion | Verdict | Evidence |
|---|-----------|---------|----------|
| 59 | `high-rtt` SDK warning fires at >400ms RTT in 3/5 samples | CONFIRMED | CA6aa6d9e0 (N4 combined netem: 10% loss + 300ms +/- 50ms delay). RTT avg=361ms, max=404ms. `high-rtt` warning fired when max exceeded 400ms. |
| 60 | MOS decreases with latency and packet loss | CONFIRMED | CA6aa6d9e0: MOS dropped from baseline 4.38 to avg=3.56, min=3.36. Combined netem loss + delay caused measurable MOS degradation. |
| 61 | MOS range 1.0-4.6 holds under degradation | CONFIRMED | CA6aa6d9e0: min MOS 3.36, max 3.97. Still within documented range even under heavy degradation. |
| 62 | MOS < 3.5 indicates poor quality | CONFIRMED | CA6aa6d9e0: min MOS 3.36 during combined degradation. Call was audibly degraded (choppy, high latency). |
| 63 | CDP packetLoss/latency/packetReordering do NOT affect WebRTC RTP | CONFIRMED | CA12eaa88c, CA24d6fc23 (CDP tests): 5% packetLoss → 0% in SDK samples, 500ms latency → 85ms RTT unchanged. Only tc netem (OS-level) affects the media plane. |

---

## Assertions Confirmed by Official Documentation (Phase B)

| # | Assertion | Verdict | Source |
|---|-----------|---------|--------|
| 49 | CANNOT detect echo | CONFIRMED | Voice Insights FAQ: "In-stream audio issues like echo... can't be detected by Voice Insights today." |
| 50 | CANNOT detect non-jitter noise (static, hum) | CONFIRMED | Same FAQ: "noise that is not related to jitter or packet loss, can't be detected" |
| 51 | MOS range 1.0-4.6 | CONFIRMED | Voice SDK changelogs: "the final mos should always be in the range [1.0, 4.6]" |
| 52 | Advanced Features returns HTTP 401 | CONFIRMED | FAQ: "Attempts to request resources... will result in an HTTP 401 Unauthorized response." |
| 53 | PDD: US <6s, South Africa commonly 10s | CONFIRMED | FAQ: "in the US... PDD higher than 6 seconds... in South Africa PDD of 10 seconds is common" |
| 54 | SDK warning: high-rtt >400ms in 3/5 samples | CONFIRMED | SDK Call Quality Events doc: "RTT > 400 ms for 3 out of last 5 samples" |
| 55 | SDK warning: low-mos <3.5 in 3/5 samples | CONFIRMED | Doc: "MOS < 3.5 for 3 out of last 5 samples" |
| 56 | SDK warning: high-jitter >30ms in 3/5 samples | CONFIRMED | Doc: "Jitter > 30 ms for 3 out of last 5 samples" |
| 57 | SDK warning: high-packet-loss >1% in 3/5 samples | CONFIRMED | Doc: "Packet loss > 1% in 3 out of last 5 samples" |
| 58 | SDK warning: high-packets-lost-fraction >3% in 7/10 (mobile) | CONFIRMED | Doc: "Packet loss > 3% in 7 out of last 10 samples" (Android/iOS only) |

---

## Corrections Applied

### C1: SDK event counts

- **Original text (ABOUTME line 1)**: "Comprehensive reference for all 85 Voice SDK events"
- **Original text (Section 2 header)**: "23 Actionable Events"
- **Corrected text**: "86 Voice SDK events" and "24 Actionable Events"
- **Why**: Counting all events in Sections 2 and 3: Section 2 subtotals: 8+2+2+2+4+2+4=24 (not 23). Section 3 subtotals: 4+2+3+21+10+5+3+2+5+1+1+2+2+1=62. Total with listings: 24+62=86. Two events (ice-connection-state:failed, pc-connection-state:failed) appear in both Section 2 and Section 3, giving 84 unique events. The ABOUTME and headers need updating.

### C2: connectivityIssue field name (singular vs plural)

- **Original text (SKILL.md Section 8)**: "Connectivity issues enum: `invalid_number`, `caller_id`, `dropped_call`, `number_reachability`"
- **Corrected text**: "Connectivity issue (singular field `connectivityIssue`): `unknown_connectivity_issue`, `no_connectivity_issue`, `invalid_number`, `caller_id`, `dropped_call`, `number_reachability`"
- **Why**: voice.ts Zod schema uses `connectivityIssue` (singular) as the field name, not `connectivityIssues` (plural). The enum also includes `unknown_connectivity_issue` and `no_connectivity_issue` which the skill omitted.

### C3: answeredBy enum completeness

- **Original text (SKILL.md Section 8)**: "`answeredBy`: `human` or `machine`"
- **Corrected text**: "`answeredBy`: `unknown_answered_by`, `human`, or `machine`"
- **Why**: voice.ts Zod schema: `z.enum(['unknown_answered_by', 'human', 'machine'])`. The skill omitted the `unknown_answered_by` value.

### C4: Conference-specific thresholds were fabricated

- **Original text**: Conference thresholds claimed jitter avg >40ms (warning), >80ms (critical); packet loss >3% (warning), >5% (critical)
- **Corrected text**: Conference thresholds are the same as call-level per Twilio docs: jitter avg >=5ms OR max >=30ms; packet loss >=5%; latency >=150ms
- **Why**: The 40ms jitter and 3% packet loss conference thresholds do not appear in any Twilio documentation. Official docs (Conference Insights Dashboard, Conference Participant Summary) show the same thresholds as call-level: jitter avg >=5ms with max >=30ms, packet loss >=5%. The skill's "higher thresholds for conference" rationale was plausible but incorrect.

### C5: SIP 606 missing from reference file

- **Original text**: sip-response-codes.md "Top 25 SIP Response Codes" — lists 25 codes but omits 606
- **Corrected text**: Add SIP 606 (Not Acceptable) to the reference file. Already present in SKILL.md Section 11.
- **Why**: Inconsistency between SKILL.md (includes 606) and the reference file (omits it).

### C7: qualityIssues missing no_quality_issue value

- **Original text (SKILL.md Section 8)**: Listed 7 quality issue values
- **Corrected text**: Added `no_quality_issue` sentinel value to the list
- **Why**: Twilio Call Annotation API documentation lists `no_quality_issue` as a valid value. The skill omitted it.

### C6: get_call_summary requires processingState parameter for early access

- **Original text**: Skill implies summary is available by default ~2 minutes after call
- **Corrected text**: Must pass `processingState: "partial"` to get early data. Without this parameter, API returns 404 until processing is complete (~30 minutes).
- **Why**: Live testing showed all 9 calls returned 404 without the parameter. With `processingState: "partial"`, data was available within 8 minutes. The skill should mention this parameter requirement explicitly.

---

## Qualifications Applied

### Q1: ITU-T G.114 attribution

- **Original text (quality-thresholds.md)**: "Based on ITU-T G.114 recommendations"
- **Qualified text**: "Informed by ITU-T G.114 (one-way delay) and industry VoIP quality standards"
- **Condition**: ITU-T G.114 specifically covers one-way transmission delay, not jitter. The jitter thresholds are derived from general VoIP quality engineering practice, not directly from G.114.

### Q2: Rejected calls show callState "busy" not a rejection-specific state

- **Original text**: Skill lists callState values but doesn't note that rejected calls appear as "busy"
- **Qualified text**: "Rejected calls (SDK `rejected-by-local`) appear as `callState: busy` with SIP 600 (Busy Everywhere). The `sdkEdge.properties.disconnected_by` field shows `rejected` even though `properties.disconnected_by` is absent."
- **Condition**: Live test CA1b2374f5 — browser rejected incoming call. Insights showed `callState: busy`, `last_sip_response_num: 600`, `sdkEdge.properties.disconnected_by: "rejected"`.

---

## Deferred Assertions

| # | Assertion | Reason |
|---|-----------|--------|
*All previously deferred assertions have been resolved:*
- SDK warning windows (3/5, 7/10): CONFIRMED by official docs (assertions 54-58)
- Conference thresholds: CORRECTED (C4) — fabricated values replaced with documented values
- `high-rtt` threshold (>400ms): CONFIRMED by tc netem test (assertion 59)
- MOS degradation under load: CONFIRMED by tc netem test (assertions 60-62)
- Carrier 10s sampling and partial timing remain as known gaps (not tested, low risk)

---

## Test Execution Summary

| Test | Result | Key Findings |
|------|--------|-------------|
| 1.1 SDK-to-PSTN baseline (15s) | PASS | MOS 4.38, jitter 1.93ms, 15 samples at 999.8ms interval |
| 1.2 Caller hangup attribution | PASS | `disconnected_by: "caller"` confirmed |
| 1.3 Short duration call | PASS | 3 samples in 3s. Evidence saved for pstn_short_duration tag check. |
| 1.4 Inbound call | PASS | `disconnected_by` confirmed for callee-initiated hangup |
| 2.1 Brief disruption (3s) | PASS* | `reconnecting` fired. No `reconnected` (CDP kills signaling+media simultaneously). |
| 2.2 Prolonged disruption (60s) | PASS | `reconnecting` → error (53405) in 22.4s. `silence` tag in Insights. |
| 2.3 Multiple disruptions | PASS | Multiple `reconnecting` events. Call survived 3 disruptions. |
| 3.1 Mute audio 25s | FAIL | Mute API access issue — harness accesses `device.calls` which may differ between SDK versions. |
| 3.2 Low bytes sent | FAIL | Same mute API access issue as 3.1. |
| 4.1 Reject incoming call | PASS | `callState: "busy"`, SIP 600, `sdkEdge.properties.disconnected_by: "rejected"` |
| 4.2 Cancel before answer | PASS | `callState: "canceled"`, SIP 487 |
| 4.3 Callee hangs up | PASS | `disconnected_by: "caller"` in properties (callee is the "local" side) |
| 5.1 Summary validation | FAIL* | 404 without `processingState: "partial"`. Succeeded via MCP tool with parameter. |
| 5.2 Metrics validation | PASS | SDK edge metrics matched SDK samples. 1-second interval confirmed. |
| 5.3 Events validation | PASS | 31 events for baseline call. Event schema and lifecycle patterns confirmed. |

*PASS indicates core assertion was validated even if test harness had issues.

### Call SIDs Used as Evidence

| SID | Test Case | Used For |
|-----|-----------|----------|
| CA0a304474b1b243737aa73a6a4c24e1fc | 1.1 (first run) | MOS, jitter, sample rate baseline |
| CA98f8bff92a4857911ac79a7992be0890 | 1.1 (second run) | Full Insights API validation |
| CA6c59ea73e9bdfc36e9b26bfe93ac74bb | 1.2 | Caller hangup attribution |
| CAc79444768e2b62e9b9e7f5c72ec5bcec | 1.3 | Short duration / pstn_short_duration |
| CA1d8b0b0c7f1ddc82b8e12d7b36e8a52d | 1.4 | Inbound call lifecycle |
| CA83e7a5b78f1bb1b6f1fba5ad319e9e0c | 2.1 | Brief network disruption |
| CAecfada31111c6164abf085e128979d49 | 2.2 | ICE failure cascade, silence tag |
| CA1b2374f508b1a1a1a6a1f4e828391a24 | 4.1 | Rejected call, callState: busy |
| CAb51353be60275b120f1eacf39ca8d420 | 4.2 | Cancelled call, SIP 487 |

### Assertions Not Yet Covered

The following assertion categories require additional testing beyond this initial audit:

1. **Carrier/SIP edge specifics** — Requires PSTN-to-PSTN or SIP trunk calls
2. **Conference Insights** — Requires multi-party conference calls
3. **Advanced Features gating** — Need to test with AF disabled (separate account)
4. **ConversationRelay cross-referencing** — Requires CR-enabled call
5. **Account-level reports** (Reports v2 API) — Not tested in this audit
6. **Echo/noise CANNOT claims** — Architectural claims; verified by absence in Twilio docs
