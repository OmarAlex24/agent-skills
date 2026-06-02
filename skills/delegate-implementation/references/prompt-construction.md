# Constructing a delegation prompt

The external agent starts with **none** of this conversation's context. It doesn't know what the user asked for, what was decided and rejected, or what the codebase conventions are unless the prompt tells it. The delegation prompt is the entire briefing — treat it like onboarding a capable contractor who starts in five minutes and has only this document. The quality of the code you get back is bounded by the quality of this prompt.

## What every delegation prompt needs

**The goal, in one or two sentences.** What is being built and why. The "why" matters because it lets the agent make sensible micro-decisions the plan didn't spell out.

**The concrete steps.** The agreed plan, as an ordered list of what to do. Specific enough to act on — name the files, functions, endpoints, data structures. "Add validation" is weak; "add a `validateOrder` function in `src/orders/validate.ts` that rejects orders with empty line items or negative totals" is actionable.

**Scope — in and out.** Which files/modules/areas the agent should touch, and explicitly what it should *not*. External agents left unscoped tend to sprawl: refactoring adjacent code, "improving" things you didn't ask about, touching unrelated files. State the boundary. "Only modify files under `src/payments/`; do not change the public API in `src/api/`."

**Conventions to follow.** Point the agent at the project's own rules so the output matches the codebase. If there's an `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, or a `docs/` directory, tell the agent to read and follow them — Codex reads `AGENTS.md` natively, but naming it in the prompt reinforces it. Call out specifics that matter for this change: error-handling style, logging approach, how to structure tests, naming conventions.

**Definition of done.** How the agent knows it succeeded, and how you'll check. "Tests pass (`npm test`), the new endpoint returns 400 on invalid input, no existing tests break." If there's a way for the agent to verify its own work (run the test suite, run a linter, hit an endpoint), tell it to do that before finishing — a self-checked implementation needs less rework.

**Constraints.** Anything that bounds the solution: no new dependencies, must stay backward compatible, must run on the existing runtime, keep it in a specific language/framework version, performance limits, things that were considered and deliberately rejected (so the agent doesn't re-propose them).

## Structure that works

A clean template:

```markdown
# Task: <one-line goal>

## Context
<2-4 sentences: what this is, why we're doing it, how it fits the system>

## Steps
1. <concrete step, naming files/functions>
2. ...

## In scope
<files/modules to change>

## Out of scope — do not touch
<files/areas to leave alone>

## Conventions
- Follow the project's AGENTS.md and docs/ for style and architecture.
- <any change-specific conventions>

## Done when
- <verifiable condition>
- <verifiable condition>
- Run <test/lint command> and confirm it passes before finishing.

## Constraints
- <e.g. no new dependencies; keep API backward compatible>
```

## Pitfalls

- **Under-specifying scope** is the #1 cause of sprawling diffs that are painful to review. Be explicit about what not to touch.
- **Assuming shared context.** Anything that lives only in this conversation — a decision made three messages ago, a constraint the user mentioned in passing — must be written into the prompt or it's invisible to the agent.
- **No verification step.** If you don't ask the agent to run tests/lint, it may hand back code that doesn't even run. Always include a self-check in the definition of done when one exists.
- **Burying the goal.** Lead with what's being built. Don't make the agent infer the objective from a list of steps.
- **Over-prescribing implementation detail** at the expense of intent. Give the agent the goal and the constraints, and let it choose the implementation where the plan doesn't care — that's what it's good at. Pin down only what actually matters.
