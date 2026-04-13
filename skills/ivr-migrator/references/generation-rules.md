---
name: "references"
description: "Twilio development skill: references"
---

# IVR Migrator Generation Rules

Rules for converting IvrTree nodes into Twilio Serverless Functions.

## File Naming

- Root node → `welcome.js` (public)
- Menu nodes → `{node-id}.protected.js` (e.g., `en-main.protected.js`)
- Business hours helper → `helpers/business-hours.private.js`
- Agent transfer handler → `agent-transfer.protected.js`

Node IDs with dashes map to file names directly: `1-2` → `1-2.protected.js`.
For readability, use the edge labels when possible: node `1` with label "Sales" → `sales.protected.js`.

## Handler Pattern

Every menu handler follows the self-referencing Gather pattern:

```javascript
exports.handler = async (context, event, callback) => {
  const twiml = new Twilio.twiml.VoiceResponse();
  const digits = event.Digits;
  const speechResult = event.SpeechResult;
  const retryCount = parseInt(event.retryCount || '0', 10);

  const voice = { voice: 'Polly.Amy', language: 'en-GB' };

  if (digits || speechResult) {
    // ROUTING: classify and redirect/respond
    const selection = classifyMenuSelection(digits, speechResult);
    switch (selection) { /* ... */ }
  } else {
    // MENU RENDER: Gather + timeout fallthrough
    if (retryCount >= 2) { /* goodbye + hangup */ }
    else { /* gather + say + timeout redirect */ }
  }

  return callback(null, twiml);
};
```

## Node Type → TwiML Rules

### `menu` / `root` nodes
- `<Gather input="dtmf speech" numDigits="1" timeout="5" speechTimeout="auto">`
- Action URL points to self with `?retryCount=${retryCount}`
- `hints` attribute from edge labels and speechKeywords
- Menu prompt from `promptText` (cleaned up for TTS)
- Each edge becomes a case in `classifyMenuSelection()`
- Timeout fallthrough: Say "no input" + redirect with `retryCount + 1`
- Max 2 retries (3 total attempts), then goodbye + hangup

### `information` nodes
- `<Say>` with the prompt text
- If edges exist: `<Redirect>` to parent or specified target
- If no edges: `<Hangup>`

### `dead_end` nodes
- `<Say>` + `<Hangup>` — inline in parent handler's switch case

### `transfer` nodes
- `<Say>` hold message
- `<Dial>` to configured number OR `<Connect><ConversationRelay>` if CR agent
- Requires user to configure actual destination

### `callback` nodes
- `<Say>` "leave your number after the beep"
- `<Record maxLength="15" finishOnKey="#" action="?afterRecord=true">`
- afterRecord handler: `<Say>` thank you + `<Hangup>`

### `hold_music` nodes
- `<Say>` hold message
- `<Play loop="3">` with hold music URL
- `<Say>` timeout message + `<Hangup>`

### `hours_check` nodes
- Import `getBusinessHours()` from private helper
- Branch on `isOpen`: open → transfer/continue, closed → message + hangup
- Helper returns `{ isOpen, schedule, department, mode }`

### `voicemail` nodes
- `<Record>` with explicit `action` URL (avoid infinite loop gotcha)

## classifyMenuSelection Pattern

```javascript
function classifyMenuSelection(digits, speechResult) {
  // DTMF mapping from edges
  if (digits === '1') return 'option_a';
  if (digits === '2') return 'option_b';

  // Speech mapping from edge speechKeywords
  if (speechResult) {
    const lower = speechResult.toLowerCase();
    if (lower.includes('keyword')) return 'option_a';
  }

  return 'unknown';
}
```

## Cycle/Redirect Handling

Nodes with `promptSummary` starting with `[Redirect to ...]` generate:
```javascript
twiml.redirect('/voice/migrated-ivr/{targetNodeHandler}');
```

## Sequential Payment IVR Patterns

Payment IVRs differ from menu trees. They're linear flows with entry+confirm loops and conditional branches. The Orange migration established these patterns:

### Entry+Confirm Handler Pattern

For nodes that collect input and confirm it (account#, ZIP, amounts, card#):

```javascript
exports.handler = async (context, event, callback) => {
  const phase = event.phase || 'entry';
  const enteredValue = event.enteredValue || '';
  
  if (phase === 'confirm') {
    const classification = classifyConfirmation(event.Digits, event.SpeechResult);
    if (classification === 'correct') {
      twiml.redirect('/orange/next-handler?...');
    } else if (classification === 'incorrect') {
      twiml.redirect('/orange/this-handler?phase=entry&...');
    } else {
      // Re-render confirm Gather
    }
  } else {
    if (event.Digits) {
      // Digits received — redirect to confirm
      twiml.redirect(`/orange/this-handler?phase=confirm&enteredValue=${event.Digits}&...`);
    } else {
      // Render entry Gather
    }
  }
};

function classifyConfirmation(digits, speechResult) {
  if (digits === '1') return 'correct';
  if (digits === '2') return 'incorrect';
  if (speechResult) {
    const lower = speechResult.toLowerCase();
    // IMPORTANT: check 'incorrect'/'no' BEFORE 'correct'/'yes'
    // because "incorrect" contains "correct" as a substring
    if (lower.includes('incorrect') || lower.includes('no')) return 'incorrect';
    if (lower.includes('yes') || lower.includes('correct')) return 'correct';
  }
  return 'unknown';
}
```

### Multi-Variant Handler Pattern

When the same IVR exists in DTMF-only and Voice+DTMF variants:

```javascript
const variant = event.variant || 'dtmf';
const isVoice = variant === 'voice';

const gatherOpts = {
  numDigits: 1,
  timeout: 5,
  action: `/orange/handler?${buildQs({ variant, ppm })}`,
};

if (isVoice) {
  gatherOpts.input = 'dtmf speech';
  gatherOpts.speechTimeout = 'auto';
  gatherOpts.hints = 'option one, option two';
} else {
  gatherOpts.input = 'dtmf';
}
```

### Query Parameter State Management

Payment flows carry state forward through the chain via query params:
- `variant` — input mode (dtmf/voice)
- `ppm` — pre-paid meter bypass
- `phase` — entry/confirm state
- `enteredValue` — collected digits
- `retryCount` — retry counter
- `amount` — payment amount in cents
- `cardLast4` — for readback in authorization
- `step` — sub-step in multi-menu handlers

Helper pattern:
```javascript
function buildQs(params) {
  return Object.entries(params)
    .filter(([, v]) => v)
    .map(([k, v]) => `${k}=${encodeURIComponent(v)}`)
    .join('&');
}
```
