---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Quality metric thresholds for Voice Insights call and conference diagnostics. -->
<!-- ABOUTME: Covers per-metric ranges, MOS computation, sampling differences, PDD behavior, and conference-specific thresholds. -->

# Voice Quality Metric Thresholds

## Per-Metric Thresholds

### Call-Level Metrics

| Metric | Good | Warning | Critical | Applicable Edges | Notes |
|--------|------|---------|----------|-------------------|-------|
| Jitter (avg) | < 5 ms | 5-15 ms | > 15 ms | All edges | Based on ITU-T G.114 recommendations |
| Jitter (max) | < 30 ms | 30-50 ms | > 50 ms | All edges | Spikes above 50 ms cause audible artifacts |
| Packet Loss | < 1% | 1-5% | > 5% | All edges | >1% causes perceptible choppiness; >5% degrades intelligibility |
| MOS | > 4.0 | 3.5-4.0 | < 3.5 | sdk_edge | Range is 1.0-4.6 (see MOS section below) |
| RTT | < 200 ms | 200-400 ms | > 400 ms | sdk_edge | Round-trip time; affects conversational flow |
| PDD | varies | > p95 | >> p95 | carrier_edge | Per-country percentile (see PDD section below) |
| Latency | < 150 ms | 150-300 ms | > 300 ms | All edges | One-way RTP traversal time |
| Audio In Level | -50 to -10 dBFS | < -50 dBFS | -Infinity / 0 | sdk_edge, client_edge | Constant level suggests muted or dead mic |
| Audio Out Level | -50 to -10 dBFS | < -50 dBFS | -Infinity / 0 | sdk_edge, client_edge | Constant level suggests no remote audio |

### Conference-Specific Metrics (Per-Participant)

Conference participant summaries report **inbound** and **outbound** metrics separately. Always check both directions to attribute the source of degradation.

| Metric | Warning | Critical | Direction Notes |
|--------|---------|----------|-----------------|
| Packet Loss | > 3% | > 5% | High outbound = participant's upstream network is bad; high inbound = participant's download path is degraded |
| Jitter (avg) | > 40 ms | > 80 ms | Conference jitter buffers absorb some jitter; higher thresholds than point-to-point |
| Jitter (max) | > 80 ms | > 100 ms | Sustained max jitter causes buffer overflow and audio drops |
| Latency | > 150 ms | > 300 ms | High latency combined with conference mixing causes jitter buffer swelling |
| MOS | < 3.5 | < 3.0 | Range 1.0-4.6; compare across participants to identify isolated vs systemic issues |
| Queue Time | > 30 s | > 60 s | `outboundTimeInQueue` for outbound participants; high values indicate capacity/routing delays |

## MOS (Mean Opinion Score)

### Range and Computation

MOS in Voice Insights ranges from **1.0 to 4.6** (not 5.0). This is an objective estimate based on ITU-T P.862 (PESQ) adapted for real-time metrics:

- **4.6**: Maximum possible score; represents virtually lossless, low-latency audio
- **4.0-4.6**: Excellent quality; no perceptible degradation
- **3.5-4.0**: Good quality; minor degradation that most users tolerate
- **3.0-3.5**: Fair quality; noticeable degradation; some users will complain
- **2.5-3.0**: Poor quality; significant degradation; most users will notice
- **1.0-2.5**: Bad quality; heavily degraded or unusable audio

### Key Properties

- **Computed once per second** on the SDK edge
- **Monotonically decreasing** with jitter and packet loss — higher jitter or loss always lowers MOS
- MOS reflects the combined effect of all network impairments; it does not distinguish between causes
- A call with low MOS but no specific jitter/loss tags may indicate a combination of borderline-but-cumulative impairments

## Sampling Rate Differences: SDK vs Gateway

Voice Insights collects metrics at different rates depending on the edge:

### SDK Edge (Client-Side)

- **Sampling interval**: Every **1 second**
- **Metrics per minute**: 60 data points
- **Temporal resolution**: High — can detect brief spikes and transient issues
- **Source**: WebRTC `getStats()` API on the client device
- **Includes**: MOS, jitter, packet loss, RTT, audio levels, ICE candidates, codec info

### Carrier / SIP Edge (Gateway-Side)

- **Sampling interval**: Every **10 seconds**
- **Metrics per minute**: 6 data points
- **Temporal resolution**: Lower — reports cumulative stats for the previous 10-second window
- **Source**: Twilio media gateway RTP statistics
- **Includes**: Jitter, packet loss, latency (no MOS — that is SDK-only)

### Implications for Diagnosis

- SDK edge has **10x the temporal resolution** of carrier/SIP edge
- A 2-second jitter spike visible in SDK metrics may be smoothed out in the 10-second carrier window
- When correlating events across edges, align on 10-second boundaries for carrier data
- SDK metrics are more useful for pinpointing *when* degradation occurred; carrier metrics confirm *whether* the carrier path was involved

## Post-Dial Delay (PDD)

### PDD Is Per-Country Percentile, Not Fixed

The `high_pdd` tag in Voice Insights does **not** fire at a fixed threshold. Instead, Twilio maintains per-destination-country percentile baselines:

- **US domestic**: Typical PDD < 6 seconds; `high_pdd` fires above ~p95 for US destinations
- **Western Europe**: Typical PDD 3-8 seconds; thresholds vary by country
- **Africa / South Asia**: Typical PDD may be 10+ seconds; the p95 threshold accounts for this
- **Island nations / satellite routes**: PDD can exceed 15 seconds and still be "normal" for that route

### Interpreting PDD

- `high_pdd` means the PDD was above the **95th percentile for that specific destination country**
- A 10-second PDD to South Africa may be normal; a 10-second PDD to a US number is abnormal
- PDD is measured from INVITE sent to first provisional response (180/183) from the carrier
- Persistently high PDD to the same destination suggests carrier routing inefficiency — escalate to Twilio Support with call SIDs

## SDK Warnings vs Insights Tagging Thresholds

SDK quality warnings are **intentionally more sensitive** than the thresholds used for Insights tagging. This enables early detection before the user perceives degradation.

| Metric | SDK Warning Trigger | Insights Tag Trigger | Ratio |
|--------|-------------------|---------------------|-------|
| Packet Loss | 1% in 3 of 5 consecutive 1-second samples | > 5% cumulative over call | SDK fires 5x earlier |
| Jitter | Sustained above 30 ms for 3+ seconds | > 15 ms average over call | SDK fires on transient spikes |
| RTT | Above 400 ms for 3+ samples | > 400 ms average over call | Similar threshold, different sampling |
| MOS | Below 3.5 for 3+ consecutive seconds | < 3.5 average over call | SDK catches brief dips |
| Audio Level | Constant level for 10+ seconds | Sustained silence over significant portion | SDK warns earlier |

### What This Means for Diagnosis

- A call can have **SDK warnings in its events** but **no Insights quality tags** on the summary — the issue was real but too brief to affect cumulative averages
- SDK warnings in the event stream indicate transient quality dips; Insights tags indicate sustained issues
- When a user reports "choppy audio for a moment," check the per-second event stream even if the summary looks clean

## Per-Edge Actionability

### sdk_edge (Most Actionable)

Reflects the client device and its local network. Issues here are usually addressable:

- Switch from WiFi to wired connection
- Close bandwidth-competing applications
- Update browser / SDK version
- Check microphone/speaker device selection
- Verify STUN/TURN server configuration

### client_edge

Reflects the Twilio Client (SDK) signaling and media path from device to Twilio:

- ICE connectivity failures → firewall / NAT configuration
- Codec negotiation issues → SDK configuration
- Audio device problems → browser permissions, device selection

### carrier_edge (Least Controllable)

Reflects the PSTN / carrier network path. Issues here are largely outside your control:

- Carrier congestion → retry or alternate routing
- PDD spikes → carrier routing issue
- SIP errors → verify number format, check carrier status
- Persistent issues → escalate to Twilio Support with call SIDs

### sip_edge

Reflects SIP trunking or SIP Interface connections. Often configuration-related:

- Codec mismatches → update trunk codec list
- Authentication failures → check credentials, IP ACLs
- NAT traversal → verify SIP trunk NAT settings
- Registration issues → check SIP domain configuration
