---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Voice Insights Reports API guide for branded calling ROI measurement. -->
<!-- ABOUTME: Covers Settings API, Phone Number Reports (async), account-level metrics, and outlier detection. -->

# Voice Insights Reports API for Branded Calling ROI

The Reports API provides aggregate call metrics at the phone number level — the right tool for measuring branded calling effectiveness at scale. Unlike individual Call Summaries (per-call), Reports give you fleet-wide answer rates, carrier block rates, and robocall percentages across all your numbers in a single API call.

**Prerequisite**: Voice Insights Advanced Features must be enabled (per-minute billing).

---

## Voice Insights Settings API

### Check Current Settings

```javascript
// MCP tool
// mcp__twilio__get_insights_settings()
```

```bash
# Direct API
curl -s -u "$TWILIO_API_KEY:$TWILIO_API_SECRET" \
  "https://insights.twilio.com/v1/Voice/Settings" | jq .
```

**Response** (live-verified, ACxx...xx, 2026-03-28):
```json
{
  "account_sid": "ACxx...xx",
  "advanced_features": true,
  "voice_trace": false
}
```

### Enable Advanced Features

```javascript
// MCP tool — WARNING: incurs per-minute billing (rounds up to next minute)
// mcp__twilio__update_insights_settings({ advancedFeatures: true })
```

```bash
curl -s -X POST -u "$TWILIO_API_KEY:$TWILIO_API_SECRET" \
  "https://insights.twilio.com/v1/Voice/Settings" \
  -d "AdvancedFeatures=true" | jq .
```

**What Advanced Features unlocks:**
- Phone Number Reports (Inbound/Outbound) — aggregate per-number metrics
- Carrier-level block rate data
- Answering machine detection metrics
- Device type breakdown
- Robocall probability scoring
- Call Summaries with extended fields (tags, annotations)
- Voice Trace enables network-level packet capture for quality debugging

**Billing**: Per-minute charge on all voice calls while enabled. Charges round up to the next minute. Enable only when actively analyzing; disable when done if cost-sensitive.

### Enable for Subaccounts

```javascript
// mcp__twilio__update_insights_settings({ advancedFeatures: true, subaccountSid: 'ACsub...' })
```

Each subaccount has independent settings. Enabling on the parent does NOT cascade to subaccounts.

---

## Phone Number Reports API

The Reports API is **async**: POST to create a report job, then GET the report by ID.

**Base URL**: `https://insights.twilio.com/v2/Voice/Reports/PhoneNumbers/`

### Create an Outbound Report

```bash
# POST creates the report job (returns immediately)
curl -s -X POST \
  -u "$TWILIO_API_KEY:$TWILIO_API_SECRET" \
  -H "Content-Type: application/json" \
  "https://insights.twilio.com/v2/Voice/Reports/PhoneNumbers/Outbound" \
  -d '{"StartTime":"2026-03-01T00:00:00Z","EndTime":"2026-03-28T23:59:59Z"}'
```

**Creation response** (live-verified):
```json
{
  "account_sid": "ACxx...xx",
  "report_id": "voiceinsights_report_01kmvtdc5nfcfacysn5vq8ma92",
  "request_meta": {
    "end_datetime": "2026-03-29T03:32:43Z",
    "filters": [],
    "start_datetime": "2026-03-22T03:32:43Z"
  },
  "status": "created",
  "url": "https://insights.twilio.com/v2/Voice/Reports/PhoneNumbers/Outbound/voiceinsights_report_01kmvtdc5nfcfacysn5vq8ma92"
}
```

### Retrieve the Report

```bash
# GET the report by ID (paginated, may take a few seconds to generate)
curl -s -u "$TWILIO_API_KEY:$TWILIO_API_SECRET" \
  "https://insights.twilio.com/v2/Voice/Reports/PhoneNumbers/Outbound/voiceinsights_report_01kmvtdc5nfcfacysn5vq8ma92"
```

### Outbound Report Fields (Live-Verified)

Each entry in the `reports` array represents one phone number:

| Field | Type | Description |
|-------|------|-------------|
| `handle` | string | Phone number (E.164) |
| `total_calls` | integer | Total outbound calls in the time window |
| `call_answer_score` | float | Percentage of calls answered (0-100). **Key ROI metric.** |
| `call_state_percentage` | object | Breakdown: `completed`, `busy`, `canceled`, `fail`, `noanswer` (each 0-100) |
| `blocked_calls_by_carrier` | array | Per-carrier block data (see below) |
| `answer_rate_device_type` | object | Answer rate by device type (`mobile`, `landline`, `unknown`) |
| `answering_machine_detection` | object | `answered_by_human_percentage`, `answered_by_machine_percentage`, `total_calls` |
| `calls_by_device_type` | object | Call count by device type |
| `long_duration_calls_percentage` | float | Percentage of calls with long duration |
| `short_duration_calls_percentage` | float | Percentage of calls with short duration |
| `potential_robocalls_percentage` | float | Percentage flagged as potential robocalls. **Key health metric.** |
| `silent_calls_percentage` | float | Percentage with no audio detected |

### Carrier Block Data Structure

```json
{
  "blocked_calls_by_carrier": [
    {
      "country": "US",
      "carriers": [
        { "carrier": "att", "blocked_calls": 0, "blocked_calls_percentage": 0.0, "total_calls": 0 },
        { "carrier": "tmobile", "blocked_calls": 0, "blocked_calls_percentage": 0.0, "total_calls": 0 },
        { "carrier": "verizon", "blocked_calls": 0, "blocked_calls_percentage": 0.0, "total_calls": 0 }
      ]
    }
  ]
}
```

This is the most actionable field for branded calling ROI: if `blocked_calls_percentage` drops after enabling branded calling on a number, that's direct evidence of impact.

### Create an Inbound Report

```bash
curl -s -X POST \
  -u "$TWILIO_API_KEY:$TWILIO_API_SECRET" \
  -H "Content-Type: application/json" \
  "https://insights.twilio.com/v2/Voice/Reports/PhoneNumbers/Inbound" \
  -d '{"StartTime":"2026-03-01T00:00:00Z","EndTime":"2026-03-28T23:59:59Z"}'
```

### Inbound Report Fields (Live-Verified)

Inbound reports have fewer fields than outbound (no carrier block data, no robocall scoring):

| Field | Type | Description |
|-------|------|-------------|
| `handle` | string | Phone number (E.164) |
| `total_calls` | integer | Total inbound calls in the time window |
| `call_answer_score` | float | Percentage of inbound calls answered |
| `call_state_percentage` | object | Breakdown: `completed`, `busy`, `canceled`, `fail`, `noanswer` |
| `silent_calls_percentage` | float | Percentage with no audio detected |

---

## Account Report (Not Available via API Key)

The Account Report endpoint (`/v2/Voice/Reports/Account`) returned 404 on GET and 405 on POST with both API key and auth token authentication during testing (2026-03-28). This endpoint may require:
- Console-based access only (dashboard view)
- Different account tier or feature flag
- Beta enrollment

**Workaround**: Aggregate phone number reports programmatically to get account-level metrics.

---

## Branded Calling Metrics (Doc-Sourced)

Per Twilio documentation, accounts with active branded calling should see additional fields in reports:

| Field path | Description |
|------------|-------------|
| `branded_calling.total_branded_calls` | Calls that displayed branded information |
| `branded_calling.percent_branded_calls` | Percentage of calls that were branded |
| `branded_calling.answer_rate` | Answer rate for branded calls |
| `branded_calling.human_answer_rate` | Human answer rate for branded calls |
| `branded_calling.engagement_rate` | Engagement rate for branded calls |
| `branded_calling.by_use_case` | Breakdown by branded calling use case |
| `stir_shaken` | SHAKEN/STIR attestation metrics with answer rates |
| `voice_integrity.enabled_calls` | Calls with Voice Integrity active |
| `voice_integrity.answer_rate` | Answer rate for Voice Integrity calls |
| `voice_integrity.bundle_sid` | Associated Trust Product SID |

**Note**: These fields were not observed in live testing (no branded calling configured on ACxx...xx). Field names are doc-sourced and should be verified when branded calling is active on the account.

---

## ROI Measurement Framework

### Before/After Comparison

The simplest ROI approach: measure phone number metrics before and after enabling branded calling.

**Baseline (before branded calling):**
1. Create an outbound report for a 30-day window before branded calling activation
2. Record per-number: `call_answer_score`, `blocked_calls_by_carrier`, `potential_robocalls_percentage`

**After branded calling:**
1. Create an outbound report for a 30-day window after branded calling activation
2. Compare the same metrics

**Key comparisons:**
| Metric | What improvement means |
|--------|----------------------|
| `call_answer_score` increase | More calls being answered (primary ROI signal) |
| `blocked_calls_percentage` decrease | Fewer calls blocked by carriers |
| `potential_robocalls_percentage` decrease | Better trust signals reducing robocall flags |
| `noanswer` percentage decrease | Recipients more likely to pick up |

### Outlier Detection

To find numbers that need attention:

```bash
# Create outbound report
REPORT_URL=$(curl -s -X POST \
  -u "$TWILIO_API_KEY:$TWILIO_API_SECRET" \
  -H "Content-Type: application/json" \
  "https://insights.twilio.com/v2/Voice/Reports/PhoneNumbers/Outbound" \
  -d "{\"StartTime\":\"$START\",\"EndTime\":\"$END\"}" | jq -r '.url')

sleep 3

# Fetch and find outliers — numbers with below-average answer rates
curl -s -u "$TWILIO_API_KEY:$TWILIO_API_SECRET" "$REPORT_URL" | \
  jq '.reports | sort_by(.call_answer_score) | .[] | {handle, call_answer_score, total_calls, potential_robocalls_percentage}'
```

**Outlier indicators:**
- `call_answer_score` below 40% on a number with >100 calls → likely spam-flagged
- `potential_robocalls_percentage` above 10% → calling patterns being flagged
- `blocked_calls_percentage` above 5% on any carrier → active carrier blocking
- `silent_calls_percentage` above 20% → may indicate voicemail dumps or connection issues

### Branded vs Non-Branded Number Comparison

If you have both branded and non-branded numbers in the same campaign:

1. Pull the outbound report (returns all numbers)
2. Separate numbers by branded status (from your Trust Product's ChannelEndpointAssignments)
3. Compare `call_answer_score` averages between the two groups
4. Statistical significance requires ~1000+ calls per group over 30+ days

---

## MCP Tools Reference

| Tool | Use for |
|------|---------|
| `mcp__twilio__get_insights_settings` | Check if Advanced Features is enabled |
| `mcp__twilio__update_insights_settings` | Enable/disable Advanced Features (billing impact) |
| `mcp__twilio__get_account_voice_report` | Account-level metrics (currently unavailable via API — see note above) |
| `mcp__twilio__get_outbound_number_report` | Per-number outbound metrics (currently uses GET; needs fix to POST) |
| `mcp__twilio__get_inbound_number_report` | Per-number inbound metrics (currently uses GET; needs fix to POST) |
| `mcp__twilio__get_call_summary` | Individual call SHAKEN/STIR and trust data |
| `mcp__twilio__list_call_summaries` | Filter calls by direction, state, time range |
| `mcp__twilio__validate_call` | Deep validation including trust indicators |

**MCP tool gap**: The `get_outbound_number_report` and `get_inbound_number_report` MCP tools currently use GET requests, but the API requires POST to create + GET to retrieve (async pattern). These tools need to be updated to support the two-step flow. Until fixed, use direct curl commands for phone number reports.

---

## Practical Workflow: Monthly Branded Calling Health Check

```bash
#!/bin/bash
# Monthly branded calling health check

# 1. Verify Advanced Features is enabled
curl -s -u "$TWILIO_API_KEY:$TWILIO_API_SECRET" \
  "https://insights.twilio.com/v1/Voice/Settings" | jq '.advanced_features'

# 2. Create outbound report for last 30 days
START=$(date -u -v-30d +%Y-%m-%dT00:00:00Z)  # macOS
END=$(date -u +%Y-%m-%dT23:59:59Z)

REPORT=$(curl -s -X POST \
  -u "$TWILIO_API_KEY:$TWILIO_API_SECRET" \
  -H "Content-Type: application/json" \
  "https://insights.twilio.com/v2/Voice/Reports/PhoneNumbers/Outbound" \
  -d "{\"StartTime\":\"$START\",\"EndTime\":\"$END\"}")

REPORT_URL=$(echo "$REPORT" | jq -r '.url')
echo "Report URL: $REPORT_URL"

# 3. Wait for report generation then fetch
sleep 5
curl -s -u "$TWILIO_API_KEY:$TWILIO_API_SECRET" "$REPORT_URL" | \
  jq '.reports[] | {
    number: .handle,
    total_calls: .total_calls,
    answer_rate: .call_answer_score,
    robocall_pct: .potential_robocalls_percentage,
    blocked: [.blocked_calls_by_carrier[]?.carriers[]? | select(.blocked_calls > 0) | {(.carrier): .blocked_calls_percentage}]
  }'
```
