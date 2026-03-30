---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Detailed response shapes, field enums, and pricing for each Lookup v2 data package. -->
<!-- ABOUTME: Reference for interpreting Lookup API responses and understanding package capabilities. -->

# Lookup v2 Data Package Reference

Complete response shapes and field enums for each data package. All response shapes verified via live testing (2026-03-29, account ACb4de2...) except where noted.

---

## Base Response (Always Returned, Free)

Every Lookup v2 request returns this structure regardless of `fields` parameter:

```json
{
  "callingCountryCode": "1",
  "countryCode": "US",
  "phoneNumber": "+14159929960",
  "nationalFormat": "(415) 992-9960",
  "valid": true,
  "validationErrors": [],
  "url": "https://lookups.twilio.com/v2/PhoneNumbers/+14159929960"
}
```

**`validationErrors` enum values:**
- `TOO_SHORT`
- `TOO_LONG`
- `INVALID_BUT_POSSIBLE`
- `INVALID_COUNTRY_CODE`
- `INVALID_LENGTH`
- `NOT_A_NUMBER`

Invalid number response (HTTP 200, not 404):

```json
{
  "phoneNumber": "+141599299600",
  "valid": false,
  "validationErrors": ["TOO_LONG"],
  "callingCountryCode": null,
  "countryCode": null,
  "nationalFormat": "41599299600"
}
```

---

## Line Type Intelligence

**Field name**: `line_type_intelligence` | **Price**: $0.008/request | **Coverage**: Worldwide

```json
{
  "lineTypeIntelligence": {
    "mobileCountryCode": "311",
    "mobileNetworkCode": "950",
    "carrierName": "Twilio - SMS/MMS-SVR",
    "type": "nonFixedVoip",
    "errorCode": null
  }
}
```

**`type` enum (12 values):**

| Type | Description | Has carrier data? |
|------|-------------|-------------------|
| `landline` | Traditional fixed line | Yes |
| `mobile` | Standard mobile | Yes |
| `fixedVoip` | VoIP tied to location (Comcast, Vonage) | Yes |
| `nonFixedVoip` | Online VoIP, no physical device (Google Voice, Twilio) | Yes |
| `personal` | Personal use designation | No |
| `tollFree` | Toll-free numbers | No |
| `premium` | Premium-rate service | No |
| `sharedCost` | Shared cost numbers | No |
| `uan` | Universal access numbers | No |
| `voicemail` | Voicemail services | No |
| `pager` | Pager devices | No |
| `unknown` | Valid but unclassified | No |

**v1 → v2 migration**: v1 had 3 types (mobile, landline, voip). v2 splits "voip" into `fixedVoip` and `nonFixedVoip`, and adds 8 non-carrier types.

---

## Caller Name (CNAM)

**Field name**: `caller_name` | **Price**: $0.01/request | **Coverage**: US only

```json
{
  "callerName": {
    "callerName": "JOHN DOE",
    "callerType": "CONSUMER",
    "errorCode": null
  }
}
```

**`callerType` enum:**
- `BUSINESS`
- `CONSUMER`
- `UNDETERMINED` (undocumented — observed on Twilio VoIP numbers)
- `null` (data unavailable)

Non-US numbers return `errorCode: 60600` without charge.

---

## SIM Swap

**Field name**: `sim_swap` | **Price**: Contact sales | **Status**: Beta | **Coverage**: US, CA, UK, DE, FR, IT, NL, ES, BR, CO

```json
{
  "simSwap": {
    "lastSimSwap": {
      "lastSimSwapDate": "2020-04-27T10:18:50Z",
      "swappedPeriod": "PT48H",
      "swappedInPeriod": true
    },
    "carrierName": "Vodafone UK",
    "mobileCountryCode": "276",
    "mobileNetworkCode": "02",
    "errorCode": null
  }
}
```

**Fields:**
- `lastSimSwapDate`: ISO-8601 timestamp. Only available in GB, DE, ES, NL. Null elsewhere.
- `swappedPeriod`: Customer-configured threshold (ISO 8601 duration, e.g., `PT48H`)
- `swappedInPeriod`: Boolean — was SIM changed within the threshold?

**Prerequisites**: Carrier registration and approval required. Returns `errorCode: 60606` without provisioning.

---

## SMS Pumping Risk

**Field name**: `sms_pumping_risk` | **Price**: Free (US/CA), $0.025/request (ROW) | **Coverage**: Worldwide

```json
{
  "smsPumpingRisk": {
    "smsPumpingRiskScore": 61,
    "carrierRiskCategory": "moderate",
    "numberBlocked": false,
    "numberBlockedDate": null,
    "numberBlockedLast3Months": null,
    "errorCode": null
  }
}
```

**`carrierRiskCategory` enum:** `low`, `mild`, `moderate`, `high`

**Important**: `smsPumpingRiskScore` and `carrierRiskCategory` are independent signals. A low-score number can have a high-risk carrier category (e.g., VoIP carriers).

**Special parameter**: `PartnerSubId` (max 64 chars) for sub-account context.

---

## Line Status

**Field name**: `line_status` | **Price**: $0.007–$0.00385 (volume tiered) | **Status**: Private Beta | **Coverage**: 140+ countries

```json
{
  "lineStatus": {
    "status": "active",
    "errorCode": null
  }
}
```

**`status` enum:**

| Value | Meaning |
|-------|---------|
| `active` | Valid and active on network (not necessarily reachable) |
| `reachable` | Active and handset connected |
| `unreachable` | Active but handset off or out of range |
| `inactive` | Not assigned to any subscriber |
| `unknown` | Status unknown (connectivity issue) |

**Data source**: Mobile network operators' Home Location Register (HLR).

---

## Identity Match

**Field name**: `identity_match` | **Price**: $0.10–$1.20/request (varies by country) | **Coverage**: US, BR, CA, UK, DE, FR, IT, NL, ES, AU

```json
{
  "identityMatch": {
    "firstNameMatch": "exact_match",
    "lastNameMatch": "high_partial_match",
    "addressLinesMatch": "exact_match",
    "cityMatch": "exact_match",
    "stateMatch": "no_data_available",
    "postalCodeMatch": "exact_match",
    "addressCountryMatch": "exact_match",
    "dateOfBirthMatch": "no_data_available",
    "nationalIdMatch": null,
    "summaryScore": 100,
    "errorCode": null,
    "errorMessage": null
  }
}
```

**Name/address match levels:** `exact_match`, `high_partial_match`, `partial_match`, `no_match`, `no_data_available`

**Other field match levels:** `exact_match`, `no_match`, `no_data_available`

**`summaryScore` mapping:**

| Score | Meaning |
|-------|---------|
| 100 | First name + last name + address all positive |
| 80 | First name + last name positive; address negative/unavailable |
| 70 | First name + address positive; last name negative/unavailable |
| 40 | First name + last name positive; address negative |
| 20 | One field positive; others negative/unavailable |
| 0 | Multiple/all fields negative |

**Required query parameters**: `FirstName`, `LastName` (minimum). Country-specific requirements vary — some require `AddressLine1`, `City`, `PostalCode`. Missing required parameters return error 60617.

**Pricing by country:**

| Country | Price | Registration required? |
|---------|-------|----------------------|
| US | $0.10 | No |
| Brazil | $0.20 | No |
| Canada | $0.28 | Yes |
| Germany | $0.40 | Yes |
| Spain | $0.40 | Yes |
| UK | $0.50 | Yes |
| France | $0.55 | Yes |
| Netherlands | $0.60 | Yes |
| Italy | $1.20 | Yes |
| Australia | TBD | Yes |

---

## Reassigned Number

**Field name**: `reassigned_number` | **Price**: $0.02–$0.0015 (volume tiered) | **Coverage**: US only | **Rate limit**: 50 RPS

```json
{
  "reassignedNumber": {
    "lastVerifiedDate": "2019-09-24",
    "isNumberReassigned": "no",
    "errorCode": null
  }
}
```

**`isNumberReassigned` enum:** `"yes"`, `"no"`, `"no_data_available"` (all strings)

**Required parameter**: `LastVerifiedDate` (YYYYMMDD format). Omitting returns error 60617.

**Database update cadence**: Monthly on the 16th. Data can be up to ~30 days stale.

**Volume pricing:**

| Volume | Price/query |
|--------|-------------|
| 0–1K | $0.02 |
| 1K–10K | $0.014 |
| 10K–50K | $0.0125 |
| 50K–200K | $0.0085 |
| 200K–500K | $0.0075 |
| 500K–2M | $0.003 |
| 2M–6M | $0.0025 |
| 6M+ | $0.0015 |

---

## Call Forwarding

**Field name**: `call_forwarding` | **Price**: Contact sales | **Status**: Private Beta | **Coverage**: UK major carriers only

```json
{
  "callForwarding": {
    "callForwardingEnabled": true,
    "errorCode": null
  }
}
```

Detects **unconditional** forwarding only. Conditional forwarding (busy, no-answer, unreachable) is not detected. Non-UK numbers return `errorCode: 60607`.

---

## Phone Number Quality Score

**Field name**: `phone_number_quality_score` | **Price**: Not publicly documented | **Status**: Limited availability

```json
{
  "phoneNumberQualityScore": {
    "carrier_risk_category": null,
    "carrier_risk_score": null,
    "disposable_phone_risk_category": null,
    "disposable_phone_risk_score": null,
    "quality_category": null,
    "quality_score": null,
    "velocity_risk_category": null,
    "velocity_risk_score": null,
    "error_code": 60606
  }
}
```

**SDK inconsistency**: This package uses **snake_case** property names in the SDK response, unlike every other package which uses camelCase. Response shape observed via live test (2026-03-29) but field values are null due to account not being provisioned.

---

## Pre-fill

**Field name**: `pre_fill` | **Price**: Not publicly documented | **Status**: Limited availability

Returns PII associated with the phone number (first name, last name, address). Accepts optional `VerificationSid` parameter for Verify API integration. Limited public documentation.

---

## Valid Field Names

The complete set of valid `fields` parameter values (confirmed via API error message, 2026-03-29):

```
validation, caller_name, sim_swap, call_forwarding, line_status,
line_type_intelligence, identity_match, reassigned_number,
sms_pumping_risk, phone_number_quality_score, pre_fill
```

Passing any other value returns HTTP 400 with this list in the error message.

---

## Query Parameters Reference

| Parameter | Used by | Format | Description |
|-----------|---------|--------|-------------|
| `Fields` | All packages | Comma-separated string | Data packages to include |
| `CountryCode` | Base | ISO 3166-1 alpha-2 | For national format input |
| `FirstName` | identity_match | Max 128 chars | Name to match |
| `LastName` | identity_match | Max 128 chars | Name to match |
| `AddressLine1` | identity_match | Max 256 chars | Address to match |
| `AddressLine2` | identity_match | Max 256 chars | Address to match |
| `City` | identity_match | Max 128 chars | City to match |
| `State` | identity_match | Max 128 chars | State to match |
| `PostalCode` | identity_match | Max 10 chars | Postal code to match |
| `AddressCountryCode` | identity_match | 2 chars | Country for address |
| `NationalId` | identity_match | Max 128 chars | Requires KYC approval |
| `DateOfBirth` | identity_match | YYYYMMDD | Date of birth to match |
| `LastVerifiedDate` | reassigned_number | YYYYMMDD | Last consent date |
| `VerificationSid` | pre_fill | SID | Verify API link |
| `PartnerSubId` | sms_pumping_risk | Max 64 chars | Sub-account context |
