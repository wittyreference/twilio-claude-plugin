# Learning Exercises

Interactive learning exercises for building comprehension of autonomous work.

## What This Is

When autonomous sessions (`/orchestrate`, subagents) produce code, you see clean artifacts but miss the decision-making process. These exercises use the **generation effect** — actively engaging with code produces deeper understanding than passive review.

## How It Works

1. Claude poses a question about code produced by autonomous work, then **STOPS**
2. You respond with your thinking
3. Claude provides feedback connecting your response to the actual code
4. If your understanding has a gap, Claude says so directly, then explores it

## Rules

- **Max 2 exercises per session** — after 2 completed, stop offering
- **Decline = suppress** — if you say "skip" or decline, no more exercises this session
- **Pause for input** — after posing a question, STOP. No hints, no examples, no leading. Wait for the user's response.

## Arguments

$ARGUMENTS

## Behavior Based on Arguments

### No arguments (empty)

1. Look for recent commits from autonomous work (subagents, orchestrate, headless)
2. Identify 2-3 interesting design decisions, patterns, or non-obvious code in the changed files
3. Generate exercise questions on the spot from the most recent autonomous changes
4. Present the list and ask which one to work on
5. When the user picks one, present the exercise question and STOP. Wait for their response.
6. After their response, provide feedback:
   - Read the actual file referenced in the exercise
   - Compare their prediction/understanding to what the code actually does
   - If they were wrong, say so directly, explain the gap, explore why
   - If they were right, confirm and optionally add deeper context

### `list`

Show potential exercises derived from recent autonomous commits without starting one. Include:
- Exercise type (Prediction, Generation, Trace, Debug)
- File path
- What changed

### `skip`

Suppress exercises for this session. Confirm: "Exercises suppressed for this session."

### `review`

Retrieval practice on code you've worked with before:
1. Pick a file the user has modified or reviewed recently
2. Ask a recall question about its behavior — NOT a reading comprehension question, a prediction question
3. STOP and wait for the user's response
4. Provide feedback by reading the actual code

### `generate`

Force generation of exercises from recent git history:
1. Read recent commits for autonomous work patterns
2. Identify design decisions, non-obvious patterns, edge cases
3. Present generated exercise questions

## Important

- The exercise question is the point of engagement. Never dilute it with hints or partial answers before the user responds.
- Be direct in feedback. If the user's understanding is wrong, say so. Genuine correction is more valuable than false validation.
