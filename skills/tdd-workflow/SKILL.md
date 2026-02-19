# TDD Workflow Patterns

Test-Driven Development patterns for Twilio projects. Load this skill when working on feature development to ensure quality through disciplined test-first practices.

## Why TDD Matters

When building Twilio integrations, TDD is especially valuable because:

1. **Quality gate**: Tests define expected behavior upfront — critical for webhook-driven flows where debugging is hard
2. **Reviewability**: Easier to review tests than implementation
3. **Confidence**: Green tests = working code
4. **Self-verification**: Validates work without manual Twilio API testing

## The TDD Cycle

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   RED ────────────► GREEN ────────────► REFACTOR           │
│    │                  │                    │                │
│    │                  │                    │                │
│  Write              Write               Improve             │
│  failing            minimal             code                │
│  tests              code to             while               │
│                     pass                keeping             │
│                     tests               tests               │
│                                         green               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Red Phase (Write Failing Tests)

Write tests that FAIL. This is critical — if tests pass before implementation, they're not testing new functionality.

**What to do:**
1. Read specification or requirements
2. Write unit tests for each function
3. Write integration tests for workflows
4. Run tests and **verify they fail**
5. Confirm failures are for the right reason (missing function, not syntax error)

```javascript
// Example: Tests that correctly fail (function doesn't exist yet)
describe('transferCall', () => {
  it('should return valid TwiML with Dial verb', () => {
    const result = transferCall({ to: '+1234567890' });
    expect(result).toContain('<Dial>');
  });

  it('should require phone number', () => {
    expect(() => transferCall({})).toThrow('Missing required: to');
  });
});
// Error: Cannot find module '../functions/voice/transfer'
```

### Green Phase (Make Tests Pass)

Write MINIMAL code to make tests pass. No more, no less.

**What to do:**
1. Verify tests exist and fail
2. Read test expectations carefully
3. Write the simplest implementation that passes
4. Run tests until green
5. Commit working code

### Refactor Phase (Improve While Green)

Improve code quality while keeping tests green.

**What's allowed:**
- Rename for clarity
- Extract methods
- Remove duplication
- Improve performance

**What's NOT allowed:**
- Add new features
- Change behavior
- Break tests

## Common TDD Pitfalls

### Pitfall 1: Tests Pass Before Implementation

**Problem**: Tests pass immediately, meaning they don't test new code.

**Cause**: Testing existing functionality or writing assertions that always pass.

**Fix**: Ensure tests reference functions/features that don't exist yet.

### Pitfall 2: Over-Testing

**Problem**: Writing too many tests that overlap in coverage.

**Cause**: Testing implementation details instead of behavior.

**Fix**: Test PUBLIC interfaces and edge cases, not private methods.

### Pitfall 3: Under-Testing

**Problem**: Tests only cover happy path.

**Cause**: Skipping error cases to make tests pass faster.

**Fix**: Requirements should define error scenarios. Test them all.

### Pitfall 4: Modifying Tests to Pass

**Problem**: Changing test expectations to match buggy implementation.

**Cause**: Pressure to make tests green without fixing root cause.

**Fix**: Tests define CORRECT behavior. Fix implementation, not tests.

## Test Categories

| Category | Location | Runs When | Coverage Target |
|----------|----------|-----------|-----------------|
| Unit | `__tests__/unit/` or `*.test.js` | `npm test` | 80%+ |
| Integration | `__tests__/integration/` | `npm test` | Key flows |
| E2E | `__tests__/e2e/` or `postman/` | `npm run test:e2e` | Critical paths |

### Unit Tests for Twilio Functions

Test individual functions in isolation. Mock the Twilio context and callback:

```javascript
const { handler } = require('../functions/voice/greeting');

describe('greeting handler', () => {
  let context, event, callback;

  beforeEach(() => {
    context = {
      getTwilioClient: jest.fn(),
      TWILIO_PHONE_NUMBER: '+15551234567'
    };
    event = { From: '+15559876543' };
    callback = jest.fn();
  });

  it('should return TwiML with Say verb', (done) => {
    callback.mockImplementation((err, response) => {
      expect(err).toBeNull();
      expect(response.toString()).toContain('<Say');
      done();
    });

    handler(context, event, callback);
  });

  it('should handle missing From number', (done) => {
    event = {};
    callback.mockImplementation((err, response) => {
      expect(err).toBeNull();
      // Should still work with a default message
      expect(response.toString()).toContain('<Say');
      done();
    });

    handler(context, event, callback);
  });
});
```

### Integration Tests

Test function interactions and webhook chains:

```javascript
describe('IVR flow', () => {
  it('should route billing calls to billing queue', async () => {
    // Step 1: Incoming call hits IVR
    const ivrResponse = await testHandler('/voice/ivr', {
      CallSid: 'CAtest123',
      From: '+15559876543'
    });
    expect(ivrResponse).toContain('<Gather>');

    // Step 2: Caller presses 1 for billing
    const routeResponse = await testHandler('/voice/ivr-handler', {
      CallSid: 'CAtest123',
      Digits: '1'
    });
    expect(routeResponse).toContain('<Enqueue');
    expect(routeResponse).toContain('billing');
  });
});
```

### E2E Tests with Real Twilio

Test against live Twilio APIs using deep validation:

```javascript
describe('Voice transfer E2E', () => {
  it('should complete transfer successfully', async () => {
    // Make a real call via Twilio API
    const call = await client.calls.create({
      to: testPhoneNumber,
      from: twilioPhoneNumber,
      url: `${baseUrl}/voice/incoming`
    });

    // Wait for call to complete
    await waitForCallStatus(call.sid, 'completed', 60000);

    // Deep validate
    const finalCall = await client.calls(call.sid).fetch();
    expect(finalCall.status).toBe('completed');

    // Check for debugger errors
    const alerts = await client.monitor.alerts.list({
      startDate: new Date(Date.now() - 300000),
      logLevel: 'error'
    });
    const relatedAlerts = alerts.filter(a => a.resourceSid === call.sid);
    expect(relatedAlerts).toHaveLength(0);
  });
});
```

## TDD with Development Agents

When using the plugin's development agents:

### test-gen Agent (Red Phase)
1. Read spec from previous phase
2. Identify test scenarios
3. Write test files with failing tests
4. Run tests to confirm failure
5. Report test count and failure status

### dev Agent (Green Phase)
1. Verify failing tests exist
2. Read test expectations
3. Write minimal implementation
4. Run tests iteratively until green
5. Commit when all tests pass

### review Agent (Verification)
The review agent checks TDD discipline:
- Were tests written before implementation?
- Were tests initially failing?
- Is the implementation minimal?
- Are there no extra features beyond what tests require?
