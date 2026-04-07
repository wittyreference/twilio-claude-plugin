---
name: "pay"
description: "Twilio development skill: pay"
---

# Pay Functions Context

**Service:** `prototype-labs` (`LABS_BASE_URL`). Deploy: `./scripts/deploy-services.sh dev`

This directory contains Twilio Pay functions for PCI-compliant payment collection during voice calls.

## Files

| File | Access | Description |
|------|--------|-------------|
| `collect-payment.protected.js` | Protected | Voice webhook returning `<Pay>` TwiML to collect credit card via DTMF |
| `payment-complete.protected.js` | Protected | `<Pay>` action URL — receives tokenized card result, returns confirmation TwiML |
| `payment-status.protected.js` | Protected | `<Pay>` statusCallback — logs payment progress events |

## PCI Mode Requirement

**WARNING**: `<Pay>` requires PCI Mode to be enabled on the Twilio account. PCI Mode is **irreversible** and **account-wide**. Always use a subaccount for payments development and testing.

## Payment Flow

```
Caller dials in
    ↓
collect-payment.protected.js → <Say> greeting → <Pay> verb
    ↓
Twilio prompts for: card number → expiry → CVV → zip (DTMF)
    ↓
payment-status.protected.js receives progress events
    ↓
payment-complete.protected.js receives tokenized result
    ↓
<Say> confirmation/failure → <Hangup>
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PAYMENT_CONNECTOR` | No | `Default` | Payment connector name |
| `PAYMENT_CHARGE_AMOUNT` | No | `0.00` | Default charge amount |
| `PAYMENT_CURRENCY` | No | `usd` | Currency code |

The `chargeAmount` can also be passed as an event parameter to override the default.

## Pay TwiML Attributes

```javascript
twiml.pay({
  paymentConnector: 'Default',     // Payment gateway connector
  chargeAmount: '9.99',            // Amount to charge
  currency: 'usd',                 // Currency code
  paymentMethod: 'credit-card',    // credit-card or ach-debit
  tokenType: 'one-time',           // one-time or reusable
  action: '/pay/payment-complete', // Receives result
  statusCallback: '/pay/payment-status', // Progress updates
});
```

## Payment Result Parameters

The `action` URL receives these parameters:

| Parameter | Description |
|-----------|-------------|
| `Result` | `success`, `payment-connector-error`, `caller-interrupted`, etc. |
| `PaymentToken` | Tokenized card (for charging via payment processor) |
| `PaymentCardNumber` | Last 4 digits |
| `PaymentCardType` | `visa`, `mastercard`, `amex`, etc. |
| `PaymentConfirmationCode` | Confirmation code from connector |

## Agent-Assisted Payment Files

| File | Access | Description |
|------|--------|-------------|
| `pay-simulator.js` | Public | Test payment processor for Generic Pay Connector (simple/robust modes) |
| `payment-status-sync.protected.js` | Protected | `<Pay>` statusCallback → writes to Sync for real-time observability |

## Agent-Assisted Payment Flow (REST API)

```
Customer on active call (e.g., in conference with CR agent)
    ↓
create_payment(callSid) → starts payment session
    ↓
update_payment(Capture=payment-card-number) → <Pay> listens for DTMF
    ↓
Customer enters card digits on phone keypad
    ↓
Status callback fires with Required field (tracks remaining fields)
    ↓
Repeat: update_payment(Capture=expiration-date), security-code, postal-code
    ↓
update_payment(Status=complete) → connector processes payment
    ↓
Status callback with Result=success or payment-connector-error
```

## Generic Pay Connector Setup

1. Console → Voice → Pay Connectors → Create Generic Pay Connector
2. Endpoint URL: `https://prototype-8922-dev.twil.io/pay/pay-simulator`
3. Username/Password: `pay_user`/`pay_pass`
4. Mode: TEST for development, LIVE for production

The connector sends POST with lowercase fields: `method`, `cardnumber`, `expiry_month`, `expiry_year`, `cvv`, `postal_code`, `amount`.

**No REST API exists for Pay Connectors** — Console-only configuration.

## Gotchas

1. **`<Pay>` only runs on inbound/webhook call legs** — Using `<Pay>` in inline TwiML on outbound API calls (`make_call` with `twiml` parameter) silently fails. Zero errors, zero callbacks, zero notifications. `<Pay>` must execute from a phone number's voice URL webhook. The `create_payment` REST API works on ANY in-progress call.

2. **Conference audio does NOT preserve DTMF signaling** — `<Play digits>` on one conference participant generates in-band audio tones. `<Pay>` on another participant only detects out-of-band RFC 2833 DTMF from its own call's phone keypad. Cannot inject DTMF across conference participants via `<Play digits>`, `announceUrl`, or muting.

3. **`<Play digits>` on a parent leg DOES reach `<Pay>` on its child** — Within a single `<Dial>`-created call pair, DTMF signaling crosses the parent/child bridge. This is the only cross-leg DTMF pattern that works.

4. **ZIP code needs `#` to terminate** — Card number auto-terminates at 16 digits, expiry at 4, CVV at 3. But ZIP codes have variable length (5 or 9), so `<Pay>` waits indefinitely. Customer must press `#` after entering ZIP.

5. **Status callback `Required` field tracks capture completion** — Comma-separated list of uncaptured fields (e.g., `"expiration-date,security-code,postal-code"`). Drops field names as captured. Becomes null/empty when ALL fields captured. Use this to know when to advance to the next field.

6. **Status callbacks fire per-digit during card entry** — `PaymentCardNumber` grows from `x` to `xxxxxxxxxxxx4242` one digit at a time. Don't use card number length to detect completion — use the `Required` field instead.

7. **Sync polling for payment state requires timestamp guards** — Status callbacks overwrite the Sync doc. Without checking that `lastUpdated > captureRequestedAt`, stale data from previous payments causes false positives.

8. **`<Pause>` as first TwiML verb doesn't answer a call** — When calling a Twilio number, the child leg's webhook must produce audio (e.g., `<Say>`) before `<Pause>`. A `<Pause>`-only response results in `no-answer`.

9. **Generic Pay Connector uses lowercase field names** — `method`, `cardnumber`, `expiry_month`, `expiry_year`, `cvv`. NOT `Method`, `CardNumber`, `ExpirationDate`.

10. **`create_payment` rejects `ChargeAmount` and `TokenType` params** — Despite being documented, passing these on the REST API returns error 64020. Use minimal params: `IdempotencyKey`, `StatusCallback`, `PaymentConnector` only.

## Operational Failure Modes

### Connector Credential Lifecycle

Pay Connectors authenticate with Twilio via tokens configured in Console. These tokens can expire or be revoked without warning.

**Detection**: `payment-connector-error` in the `Result` field of status callbacks. No specific error code distinguishes credential failure from other connector errors — you must infer from timing (works one day, fails the next without code changes).

**Mid-collection failure**: If a connector token expires while a customer is actively entering card data, the `<Pay>` session continues collecting DTMF digits but tokenization fails on submission. The customer has entered their full card number into a system that cannot process it. Combined with gotcha #4 (maxAttempts forces full re-entry), this creates a frustrating experience where the customer must re-enter all fields.

**Recovery patterns**:
1. **Pre-call health check**: Before initiating payment flows, call the connector's tokenization endpoint with a test payload. If it fails, route the caller to a human agent instead of entering `<Pay>`.
2. **Timeout detection**: If `<Pay>` status callbacks stop arriving for >10 seconds during active collection, the connector may be unresponsive. Use the `update_payment` API to cancel and route to fallback.
3. **Credential rotation**: Connectors configured in Console have no rotation API. Set calendar reminders for token expiration. When rotating, update the connector in Console and test immediately — there is no staging environment for Pay Connectors.

**Cascade**: Connector failure → customer data entered but not tokenized → no PCI-compliant record of the attempt → compliance gap in payment audit trail.

## File Naming Conventions

- `*.js` - Public endpoints (voice webhooks Twilio calls directly)
- `*.protected.js` - Protected endpoints (action URLs, status callbacks)
