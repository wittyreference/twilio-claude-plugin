---
name: workflows
description: Development workflow patterns for Twilio projects. Pipeline definitions for new features, bug fixes, refactors, security audits, and documentation. Includes when to use orchestrated vs team-based vs standalone agents.
---

# Development Workflows

This document describes the available workflow patterns for developing Twilio features using Claude Code subagents.

## Available Subagents

| Command | Role | Description |
|---------|------|-------------|
| `/orchestrate` | Workflow Coordinator | Runs full development pipelines automatically |
| `/architect` | Architect | Design review, pattern selection, unknowns identification |
| `/prototype` | Prototyper | Quick spike to test unknowns — no tests, produces learnings |
| `/spec` | Specification Writer | Creates detailed technical specifications |
| `/test-gen` | Test Generator | TDD Red Phase - writes failing tests first |
| `/dev` | Developer | TDD Green Phase - implements to pass tests |
| `/review` | Senior Developer | Code review, security audit, approval authority |
| `/test` | Test Runner | Executes and validates test suites |
| `/docs` | Technical Writer | Documentation updates and maintenance |
| `/deploy` | Deployment Helper | Pre/post deployment checks |
| `/twilio-docs` | Documentation Lookup | Searches Twilio documentation |
| `/twilio-logs` | Log Analyzer | Fetches and analyzes Twilio debugger logs |

## Workflow Patterns

### New Feature Pipeline

Full development pipeline for building new Twilio functionality:

```text
/architect ──► /prototype (if unknowns) ──► /spec ──► /test-gen ──► /dev ──► /review ──► /test ──► /docs
```

**Orchestrated**: `/orchestrate new-feature [description]`

**Manual execution**:

1. `/architect [feature]` - Get architecture review, identify unknowns
2. `/prototype [unknowns]` - Quick spike to test unfamiliar APIs *(skip if no unknowns)*
3. `/spec [feature]` - Create detailed technical specification
4. `/test-gen [feature]` - Generate failing tests (TDD Red)
5. `/dev [feature]` - Implement to pass tests (TDD Green)
6. `/review` - Code review and security audit
7. `/test` - Run full test suite
8. `/docs` - Update documentation

### Bug Fix Pipeline

Quick fix pipeline for resolving issues:

```text
/twilio-logs ──► /architect ──► /test-gen ──► /dev ──► /review ──► /test
```

**Orchestrated**: `/orchestrate bug-fix [issue]`

**Manual execution**:

1. `/twilio-logs` - Analyze debugger logs to identify the issue
2. `/architect [diagnosis]` - Determine fix approach
3. `/test-gen [regression]` - Write regression tests
4. `/dev [fix]` - Implement the fix
5. `/review` - Validate the fix
6. `/test` - Verify all tests pass

### Refactor Pipeline

Improve code structure without changing behavior:

```text
/test ──► /architect ──► /dev ──► /review ──► /test
```

**Orchestrated**: `/orchestrate refactor [target]`

**Manual execution**:

1. `/test` - Verify existing tests pass (baseline)
2. `/architect [refactor plan]` - Design the refactoring approach
3. `/dev [refactor]` - Implement changes
4. `/review` - Validate changes
5. `/test` - Confirm behavior unchanged

### Documentation Only

```text
/docs
```

**Orchestrated**: `/orchestrate docs-only [scope]`

### Security Audit

```text
/review ──► /dev ──► /test
```

**Orchestrated**: `/orchestrate security-audit [scope]`

## Standalone vs Orchestrated

All subagents work independently. Choose the approach that fits your workflow:

### Orchestrated Mode

Use `/orchestrate` when:

- Building a complete new feature with sequential phases
- Following a standard workflow pattern
- Want automated sequencing and handoffs
- Working on a well-defined task

### Standalone Mode

Run individual subagents when:

- Working on a specific phase only
- Need more control over the process
- Task doesn't fit standard patterns
- Iterating on a particular aspect

## TDD Enforcement

This workflow strictly follows Test-Driven Development:

1. **Red Phase** (`/test-gen`): Write failing tests first
2. **Green Phase** (`/dev`): Write minimal code to pass tests
3. **Refactor**: Improve code while keeping tests green

The `/dev` subagent will verify that failing tests exist before implementing. If no tests exist, it will suggest running `/test-gen` first.

## Handoff Protocol

Each subagent suggests the next logical step:

| After | Suggests |
|-------|----------|
| `/architect` | `/prototype` (if unknowns) or `/spec` (if no unknowns) |
| `/prototype` | `/spec` for detailed specification |
| `/spec` | `/test-gen` for test generation |
| `/test-gen` | `/dev` for implementation |
| `/dev` | `/review` for code review |
| `/review` (APPROVED) | `/test` for final validation |
| `/review` (NEEDS_CHANGES) | `/dev` for fixes |
| `/test` | `/docs` for documentation |

## Best Practices

1. **Always start with `/architect`** for new features to ensure proper design
2. **Prototype unknowns first** — if the architect identifies unfamiliar APIs or ambiguous behavior, spike them before writing a spec
3. **Use `/spec`** to clarify requirements before writing code
4. **Never skip `/test-gen`** - tests must exist before implementation
4. **Run `/review`** before merging any significant changes
5. **Keep `/docs`** updated as features evolve
6. **Use `/twilio-logs`** when debugging production issues
