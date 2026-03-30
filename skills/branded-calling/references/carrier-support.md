---
name: "references"
description: "Twilio development skill: references"
---

<!-- ABOUTME: Carrier support matrix for Branded Calling, SHAKEN/STIR, Voice Integrity, and CNAM. -->
<!-- ABOUTME: Covers T-Mobile, AT&T, Verizon, and Apple/iOS device-level behavior. -->

# Carrier & Device Support Matrix

Branded Calling display is not universal. Whether the recipient sees your business name, logo, and call reason depends on carrier, device, OS, and the type of branding registered.

---

## Branded Calling Display Support

### Basic Branded Calling (Business Name)

| Carrier | Android | iPhone/iOS | Landline |
|---------|---------|------------|----------|
| T-Mobile | Supported (native dialer) | Supported (native dialer, iOS 18+) | Not supported |
| AT&T | Limited (via ActiveArmor app) | Limited (via ActiveArmor app) | Not supported |
| Verizon | Limited (via Call Filter app) | Limited (via Call Filter app) | Not supported |
| MVNOs (T-Mobile network) | Varies | Varies | Not supported |

**Key points:**
- T-Mobile has the broadest native support — no app required
- AT&T and Verizon support is primarily through their anti-spam apps, which must be installed and active
- Landlines do not support Branded Calling (use CNAM instead)
- MVNO support depends on the underlying network operator

### Enhanced Branded Calling (Name + Logo + Call Reason)

| Carrier/Platform | Logo | Call Reason | Long Display Name |
|-----------------|------|-------------|-------------------|
| T-Mobile (Android) | Supported | Supported | Supported |
| T-Mobile (iOS) | Supported (iOS 18+) | Supported (iOS 18+) | Supported |
| Apple/iOS (all carriers) | Supported via Apple Business Connect | Supported (limited) | N/A |
| AT&T | Not natively supported | Not natively supported | Not natively supported |
| Verizon | Not natively supported | Not natively supported | Not natively supported |

**Apple/iOS notes:**
- Apple Business Connect is a separate registration that enables rich call display on all iOS devices regardless of carrier
- Apple reviews logo submissions independently (additional approval process)
- The `category_apple` field in the Enhanced policy accommodates Apple's category system
- Apple support expands reach beyond T-Mobile but adds review complexity

---

## SHAKEN/STIR Carrier Verification Display

SHAKEN/STIR affects how carriers display or flag calls, but the display is carrier-specific:

| Carrier | Verified indicator | How it shows |
|---------|-------------------|--------------|
| T-Mobile | Checkmark or "Verified" badge | Native dialer on Android and iOS |
| AT&T | "Valid Number" label | AT&T Call Protect / ActiveArmor |
| Verizon | Checkmark badge | Verizon Call Filter |
| Other | Varies | Depends on carrier implementation |

**Without SHAKEN/STIR A-level attestation**, calls are more likely to be:
- Flagged as "Spam Risk" or "Scam Likely"
- Sent to voicemail by carrier-side spam filters
- Blocked entirely by aggressive spam filtering apps

---

## Voice Integrity Coverage

Voice Integrity registers your numbers directly with carrier spam databases:

| Carrier | Registration method | Remediation timeline |
|---------|-------------------|---------------------|
| T-Mobile | Direct registration via Twilio | 3-7 business days |
| AT&T | Direct registration via Twilio | 3-7 business days |
| Verizon | Direct registration via Twilio | 3-7 business days |

Voice Integrity does NOT cover:
- Third-party spam apps (Hiya, Nomorobo, RoboKiller) — these maintain independent databases
- International carriers
- Landline spam filtering (less common)

---

## CNAM Coverage

CNAM (Caller Name) is the traditional caller ID system:

| Destination | Support | Display |
|-------------|---------|---------|
| Landlines | Broad (most US carriers) | 15-char business name |
| Mobile (T-Mobile) | Supported | 15-char name (overridden by Branded Calling if active) |
| Mobile (AT&T) | Supported | 15-char name |
| Mobile (Verizon) | Supported | 15-char name |
| VoIP providers | Varies | Depends on provider's CNAM lookup |

**CNAM vs Branded Calling priority:**
- If both CNAM and Branded Calling are configured, Branded Calling display takes priority on supported carriers/devices
- CNAM serves as the fallback for carriers/devices that don't support Branded Calling
- For landline-heavy call audiences, CNAM is the primary caller ID mechanism

---

## Relative Impact by Layer

Exact reach percentages are not published by Twilio or carriers. The relative impact ranking (from broadest to narrowest reach) is:

1. **Voice Integrity** — Broadest impact. Covers all three major US carriers directly. Prevents and remediates spam labels.
2. **SHAKEN/STIR** — Wide impact. Provides verified attestation across all carriers that support the standard.
3. **CNAM** — Broad for landlines. Ubiquitous on landlines, supported on mobile but limited to 15 chars.
4. **Basic Branded Calling** — Narrower. Primarily effective on T-Mobile (largest native support).
5. **Enhanced Branded Calling** — Narrowest but richest. T-Mobile native + Apple Business Connect on iOS.

**Recommendation**: Deploy all layers for maximum coverage. Voice Integrity + SHAKEN/STIR provide the broadest impact on answer rates. Branded Calling adds visibility where supported.

---

## Testing Branded Display

### Before Going Live

1. **Test from a branded number to a T-Mobile device** — Highest probability of display
2. **Test to multiple carriers** — AT&T, Verizon, T-Mobile
3. **Check Voice Insights** after test calls:
   ```
   mcp__twilio__get_call_summary(callSid) → check stir_verstat, branded fields
   ```
4. **Allow propagation time** — New branding registrations may take 24-72 hours to display

### Verifying SHAKEN/STIR on Inbound

When receiving calls, check the webhook parameters:
- `StirVerstat` — The attestation level
- `StirPassportToken` — The raw SHAKEN passport

```javascript
// In your webhook handler
exports.handler = function (context, event, callback) {
  console.log('SHAKEN/STIR verification:', event.StirVerstat);
  // 'TN-Validation-Passed-A' = full attestation
  // 'TN-Validation-Passed-B' = partial
  // 'TN-Validation-Passed-C' = gateway only
  // 'TN-Validation-Failed' = failed verification
  // 'No-TN-Validation' = no SHAKEN/STIR present

  const twiml = new Twilio.twiml.VoiceResponse();
  twiml.say('Hello');
  callback(null, twiml);
};
```
