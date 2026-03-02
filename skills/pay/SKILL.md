---
name: pay
description: Twilio Pay functions for PCI-compliant DTMF payment collection during voice calls.
---

# Pay Skill

Twilio Pay functions for PCI-compliant DTMF payment collection during voice calls.

## PCI Mode Requirement

**WARNING**: `<Pay>` requires PCI Mode to be enabled on the Twilio account. PCI Mode is **irreversible** and **account-wide**. Always use a subaccount for payments development and testing.

## Payment Flow

```
Caller dials in
    ↓
Webhook → <Say> greeting → <Pay> verb
    ↓
Twilio prompts for: card number → expiry → CVV → zip (DTMF)
    ↓
Status callback receives progress events
    ↓
Action URL receives tokenized result
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
