---
name: "adversarial-review"
description: "Twilio development skill: adversarial-review"
---

---
name: adversarial-review
description: Four-phase adversarial review — initial expert assessment, isolated advocate + critic, objective arbiter synthesis. Use for technology adoption decisions, architectural changes, process changes, or any decision that benefits from structured debate.
---

# Adversarial Review

A structured four-phase decision analysis for significant technical or strategic questions. Produces a balanced, evidence-based recommendation by having isolated agents argue opposing positions before an objective arbiter synthesizes.

## When to Use

- Technology adoption decisions (new DB, framework, tool, service)
- Architectural changes with significant trade-offs
- Process or workflow changes affecting team productivity
- Any decision where confirmation bias is a risk
- When the question is "should we do X?" and X has meaningful costs and benefits

## When NOT to Use

- Bug fixes, implementation details, naming conventions
- Decisions where one option is obviously correct
- Time-sensitive issues requiring immediate action
- Questions with insufficient data to meaningfully debate

## Phase 1: Initial Assessment

Launch Explore agents (1-3 depending on scope) to gather facts:

- **Codebase evidence**: What exists today? What are the current pain points? What has been tried?
- **External research**: What does the literature say? What have peers done? What's the state of the art?
- **Quantitative data**: Sizes, counts, frequencies, costs, timelines — not vibes

Write the initial assessment to the plan file with these sections:

1. **Context**: Why this question now, what prompted it
2. **Current State**: How things work today, with measured data
3. **Research Findings**: What external sources say, with citations
4. **Symptom Analysis**: What's broken, what works, would the proposed change help each symptom?
5. **Cost-Benefit Analysis**: Concrete benefits vs concrete costs, not aspirational vs abstract
6. **Technology Options**: If adopting, what specific stack? If not, what alternatives?
7. **Preliminary Recommendation**: Author's honest take, clearly labeled as preliminary

**Quality bar**: The initial assessment must contain at least 3 quantitative data points from the actual codebase and at least 5 external sources with URLs. Assertions without evidence should be flagged as assumptions.

## Phase 2: Isolated Reviews (Parallel)

Launch **two agents simultaneously**, each reading ONLY the initial assessment. They must NOT see each other's work.

### Agent A: The Advocate (argues FOR the proposed change)

Persona: Senior specialist in the domain under consideration. Deep production experience with the proposed technology. Has seen it work.

Instructions to include in the agent prompt:
- Read the initial assessment (provide the plan file path)
- Explore the codebase independently to verify AND extend the claims
- Perform independent web research (different queries than Phase 1)
- **Validate and extend**: Where the assessment is right, add depth. Where it missed arguments, fill them in
- **Make the affirmative case** with specific codebase evidence — point to concrete instances where the proposed change would solve problems the current system cannot
- **Address any "wait" or "defer" recommendation critically** — what is the cost of waiting? What compounds? What becomes harder later?
- **Provide technology recommendations** beyond the initial assessment
- **Cite real-world precedent** — who has done this and what were the results?
- **Quantify opportunity cost** of inaction
- Tone: rigorous academic advocacy, not sales. Acknowledge genuine counterarguments.
- Target: 3,000-5,000 words with sources

### Agent B: The Critic (argues AGAINST the proposed change)

Persona: Senior systems engineer with 15+ years of production infrastructure experience. Has seen multiple hype cycles. Specializes in evaluating when NOT to adopt.

Instructions to include in the agent prompt:
- Read the initial assessment (provide the plan file path)
- Explore the codebase to find evidence that the current system is more capable than presented
- Perform independent web research focused on failures, anti-patterns, hidden costs
- **Identify unstated assumptions** — where does the assessment assume quality will be high? Where does it conflate "could help" with "will help"?
- **Challenge each "would help" claim** with a simpler alternative
- **Quantify hidden costs** the assessment glosses over (maintenance, monitoring, integration, opportunity cost)
- **Argue the timing is wrong** — what's evolving in the platform/ecosystem that could make this redundant?
- **Propose the "improve what we have" path** with specific, scoped improvements and effort estimates
- **Define actual triggers** for revisiting — measurable conditions, not arbitrary thresholds
- Tone: respectful but rigorous. Not dismissive — point out unstated assumptions, unsupported assertions, and cheaper alternatives.
- Target: 3,000-5,000 words with sources

**Critical**: Neither agent should be told the other exists. Each anchors only on the initial assessment and their own research.

## Phase 3: Arbiter Synthesis

Launch a **single agent** that reads all three documents (initial + advocate + critic).

Persona: PhD-level domain expert with no financial interest in any option. Has both built and maintained the proposed technology at scale, and has also seen it fail. Direct production experience. No patience for hand-waving.

Instructions to include in the agent prompt:
- Read all three documents (provide paths to initial assessment + both reviews)
- Explore the codebase to verify material factual claims from all reviewers
- Perform independent web research to verify contested claims
- **Evaluate each reviewer**: Strengths, weaknesses, overstated arguments, understated risks
- **Resolve contradictions**: Where advocate and critic directly contradict, determine which position is better supported by evidence. When evidence is ambiguous, say so
- **Verify factual claims**: Spot-check specific numbers, quotes, and assertions. Report as Verified / False / Partially Correct / Unverifiable
- **Make the final recommendation**:
  - Should the project adopt now? (Yes / No / Conditional)
  - If yes: what specific technology?
  - If no: what should be done instead, in priority order?
  - What is the empirical trigger for revisiting?
  - Does the "smell test" pass? (Is this solving a real problem or gold-plating?)
- **The coffee conversation**: What would you tell the maintainer informally? What patterns from your career map to this situation?
- Tone: direct, experienced, calls out weak arguments from any reviewer.
- Target: 4,000-6,000 words with sources

## Phase 4: Consolidation

After the arbiter completes:

1. Update the plan file with consolidated summaries of all four perspectives
2. Link to full unabridged reviews (kept as separate agent-generated files)
3. Present the arbiter's final recommendation with the key contradiction resolutions

## Output Structure

The final plan file should contain:
- Part I: Initial Assessment (full)
- Part II: Advocate Review (summarized key arguments + link to full)
- Part III: Critic Review (summarized key arguments + link to full)
- Part IV: Arbiter's Final Assessment (full)
- Appendix: Links to unabridged agent reviews

## Calibration Notes

- The initial assessment author should aim for genuine uncertainty, not pre-commitment to either side
- The advocate should be the strongest possible version of the "yes" case — steelman, not strawman
- The critic should be the strongest possible version of the "no" case — identify real risks, not FUD
- The arbiter should disagree with both reviewers on at least one point — if they don't, they're not being independent
- All four phases should produce new evidence (web searches, codebase exploration) not just restate each other
