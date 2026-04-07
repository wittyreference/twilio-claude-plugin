---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Adversarial assertion audit for conference skill with CONFIRMED/CORRECTED/QUALIFIED verdicts. -->
<!-- ABOUTME: 155 factual claims extracted, classified, and pressure-tested with SID evidence. -->

# Conference Skill — Assertion Audit

**Skill**: conference
**Audit date**: 2026-03-24
**Account**: ACxx...xx (redacted)
**Intelligence Service**: GA7d01ec96bcecc500d42d19f07e54f102
**Auditor**: Claude + MC

## Summary

| Verdict | Count |
|---------|-------|
| CONFIRMED | 42 |
| CORRECTED | 1 |
| QUALIFIED | 6 |
| DOC-SOURCED | 106 |
| **Total** | **155** |

**DOC-SOURCED** means: sourced from authoritative Twilio documentation, not independently verified by our live tests. These are not speculative — they come from the API reference, TwiML docs, or Console docs. Future audit passes should prioritize testing the highest-risk DOC-SOURCED items (rate limits, failure modes, boundary conditions).

## CONFIRMED Assertions (42 — with SID evidence)

| # | Assertion | Evidence |
|---|-----------|----------|
| 4 | Conference lifecycle: init → in-progress → completed (terminal) | CF669a... completed, never reactivated |
| 9 | reasonConferenceEnded=conference-ended-via-api triggered by API | CFf14c... ended via API |
| 10 | reasonConferenceEnded=participant-with-end-conference-on-exit-left | CF669a... / CA679e... |
| 13 | reasonConferenceEnded=last-participant-left | CF736b... / earlier tier 2 test |
| 14 | callSidEndingConference correctly identifies triggering participant | CF669a... → CA679e... (customer) |
| 26 | Muted participant CAN hear conference, conference CANNOT hear them | CFf14c... / A1 test |
| 27 | Muted participant does NOT hear hold music | CFf14c... / A1 (no hold behavior) |
| 28 | Held participant CANNOT hear conference, conference CANNOT hear them | CFf14c... / A3 test |
| 29 | Held participant hears HoldUrl audio if set | CFf14c... / A4 test with custom HoldUrl |
| 30 | Mute and Hold are independent states | CFf14c... / A6 (simultaneous mute+hold on different participants) |
| 37 | Duplicate participantLabel causes error 16025, participant does NOT join | CF897c... / NO5a67... debugger alert |
| 40 | endConferenceOnExit=true causes ENTIRE conference to end | CF669a... / C5 test |
| 42 | update_call(twiml) immediately removes participant from conference | CFa6d4... / D3 test / CAe5ab... |
| 51 | Completed conference REST API returns empty participants | CFf14c..., CF736b..., CF669a... all empty |
| 52 | Conference Insights is the ONLY post-flight participant data source | Insights returned full data; REST returned empty |
| 60 | Warm transfer: both parties endOnExit=true means either hangup ends call | CF669a... / C5 |
| 61 | Warm transfer: Agent1 endOnExit=false allows Agent1 to leave without killing conf | CF669a... / C3-C4 |
| 66 | Updating participant TwiML exits conference | CFa6d4... / D3 |
| 88 | Coaching: supervisor joins with coaching=true | CFc7db... / CA9d27... |
| 89 | Coaching: supervisor hears ALL conference audio | CFc7db... / B1-B2 |
| 90 | Coaching: ONLY coached participant hears supervisor | GT6e8b15... Intelligence: only 2 voices in 3-party coaching |
| 91 | Other participants hear nothing from coach | GT6e8b15... Intelligence confirmed |
| 92 | Barge: Coaching=false makes supervisor audio go to full mix | CFc7db... / B3 |
| 93 | Retarget coaching: update callSidToCoach dynamically | CFc7db... / B4 |
| 95 | Hold=true isolates participant from conference audio | CFf14c... / A3 |
| 96 | Held participant hears HoldUrl audio | CFf14c... / A4 |
| 97 | Other participants cannot hear held participant | CFf14c... / A3 |
| 98 | Held participant cannot hear conference | CFf14c... / A3 |
| 100 | Hold/unhold events tracked in Insights | CFcd12a... Insights events: hold/unhold timestamps |
| 114 | REST API returns empty participants for completed conferences | Multiple conferences confirmed |
| 115 | Insights is ONLY source for post-flight participant records | Confirmed across all test groups |
| 118 | Insights requires ≥1 call leg; 0-participant conferences return 404 | Tier 1: 17:28 batch had 0 participants → 404 |
| 121 | processing_state in_progress means data still being aggregated | Observed in_progress → complete transition |
| 122 | processing_state complete means analysis finished | All test conferences eventually reached complete |
| 127 | Quality metrics (MOS, jitter, latency) populated in complete state | MOS 4.35-4.4, jitter avg 0.01-0.05, latency 0.39-101.08 |
| 139 | Conference Summary includes all documented fields | get_conference_summary returned full schema |
| 140 | Insights tracks hold/unhold/mute events with timestamps | Participant summary events confirmed |
| 142 | Participant Summary includes quality metrics per-participant | Inbound/outbound jitter, latency, MOS, packet loss confirmed |
| 148 | Conference recording does NOT capture coaching audio | GT6e8b15... Intelligence: only 2 voices in 3-party coaching |
| 149 | endConferenceOnExit can be changed dynamically via participant update | CF669a... / C3 |
| 150 | Conference survives Agent1 departure with endOnExit=false | CF669a... / C4 |
| 152 | 3 participants can exist simultaneously in a conference | CFc7db... / B2 (count=3) |
| 153 | Unmute sets muted=false | CFf14c... / A2 |
| 154 | Unhold sets hold=false | CFf14c... / A5 |

## CORRECTED Assertions (1)

### #36: startConferenceOnEnter=false behavior

**Original claim**: "If all participants have startConferenceOnEnter=false, the conference stays in `init` permanently."

**Actual behavior**: Conference status showed `in-progress` with participants `muted: false` and `status: connected`. The REST API does not reflect the expected `init` state or auto-mute.

**Evidence**: CFb40284... (conf-val-D2), both participants startConferenceOnEnter=false, conference status=in-progress

**Correction applied**: Gotcha #2 in SKILL.md updated to note that REST API may show `in-progress` with `muted: false` even when all participants have startConferenceOnEnter=false — the API state does not reliably reflect the audio-level behavior.

## QUALIFIED Assertions (6)

### #43/#67: TwiML update + endConferenceOnExit=true teardown
**Claim**: If a TwiML-updated participant had endConferenceOnExit=true, the whole conference tears down.
**Caveat**: D3 confirmed TwiML update exits conference, but was tested with endConferenceOnExit=false. The combination with endConferenceOnExit=true was not independently tested. Logically follows from #42 + #40 but not directly observed.

### #62: Moderated conference init state
**Claim**: Participants with startConferenceOnEnter=false wait in `init` hearing hold music.
**Caveat**: D2 showed conference status as `in-progress` even when all participants had startConferenceOnEnter=false. The moderated pattern's reliance on `init` state may not match REST API representation. Audio-level behavior may still match docs.

### #94: Coaching Insights events
**Claim**: Insights tracks Coaching/Coaching stopped/Coaching modified events.
**Caveat**: Our Insights data confirmed hold/unhold/mute events but we did not explicitly verify coaching-specific event names in the Insights response. The coaching test conference (CFc7db...) Insights data should be checked when processing completes.

### #124/#125: Insights timing
**Claim**: Insights records took 15-30+ minutes to appear; "within minutes" is aspirational.
**Caveat**: Based on our single test session observation. Timing may vary by load, region, or account. The claim reflects our experience on ACxx...xx on 2026-03-24.

### #155: processing_state naming inconsistency
**Claim**: Insights uses "in_progress" and "complete" for processing_state.
**Caveat**: The Conference Summary API section had "partial" instead of "in_progress". This was a typo in our documentation, now corrected.

## High-Priority DOC-SOURCED Items for Future Testing

These 106 items are authoritative but untested. Highest-risk candidates for next audit pass:

| # | Assertion | Risk | Why |
|---|-----------|------|-----|
| 5 | Only one in-progress conference per friendlyName | HIGH | Name collision could silently merge callers |
| 25 | Reusing active friendlyName merges callers | HIGH | Related to #5, could cause data leakage |
| 44 | Participants API to Twilio number invokes voice URL | HIGH | Common gotcha in the codebase |
| 48/106 | 1 CPS rate limit for Participants API | MEDIUM | Could hit in production |
| 50 | waitUrl failure breaks conference silently | HIGH | Silent failure mode |
| 53 | ConferenceSid-based creation fails if not active | MEDIUM | Error behavior |
| 99 | waitUrl does NOT auto-loop | MEDIUM | Hold music cuts out |
| 101 | AnnounceUrl plays to specific participant only | MEDIUM | Audio routing claim |
| 108 | TwiML Conference is not rate-limited | MEDIUM | Scale planning |
