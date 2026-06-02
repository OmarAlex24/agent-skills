---
name: pr-review-orchestrator
description: Orchestrate a multi-agent code review of a pull request or diff. Use whenever the user opens, asks to review, or wants feedback on a PR, MR, diff, branch, or set of staged/committed changes — phrasings like "review this PR", "revisa este PR", "check my changes before I merge", "spawn agents to look at my diff", or "audit this branch". Spawns specialized subagents that hunt for bugs and correctness issues, look for ways to simplify, verify the change matches the project's docs/conventions (flagging undocumented or unjustified deviations), and assess software-design quality (coupling, cohesion, abstraction, SOLID, design patterns). Use this even when the user only says "review my code" in the context of a PR or pre-merge check, not just when they name the agents explicitly.
---

# PR Review Orchestrator

This skill turns Claude into a **review coordinator**. Given a PR (or any diff/branch), Claude spawns several specialized subagents in parallel, each with a narrow mandate, then synthesizes their findings into a single prioritized report. The point of fanning out is the same reason a good engineering team does multiple review passes: a reviewer hunting for null-pointer bugs is in a different headspace than one judging whether a module is too tightly coupled, and asking one agent to do both at once produces shallow results on both. Separate mandates keep each pass deep.

The orchestrator's job is to gather context once, route it to the right reviewers, and merge what comes back — not to do the reviewing itself. Think of yourself as the senior engineer running the review meeting, not the only person in the room.

## When subagents aren't available

This skill assumes a coding-agent environment (Claude Code, Cowork, Droid, etc.) where you can spawn parallel subagents/tasks. If you're somewhere without that capability, **don't refuse** — run the same review passes sequentially yourself, one mandate at a time, keeping each pass mentally isolated so you don't blur correctness review into design review. The output format is identical. The rest of this doc is written for the parallel case; collapse it to serial where needed.

## Step 1 — Gather context once

Before spawning anything, collect the shared material every reviewer needs. Doing this once (rather than letting five subagents each re-run `git diff`) saves time and guarantees they all review the same snapshot.

Collect:
- **The diff.** `git diff <base>...<head>` or the PR's changed files. Default base is the repo's main branch (`main`/`master`) unless the user says otherwise. For a local pre-merge check, `git diff --staged` or `git diff main...HEAD`.
- **The PR description / commit messages.** These state *intent*. A reviewer can't judge whether code matches its purpose without knowing the purpose.
- **The project conventions.** Look for `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `docs/`, ADRs (`docs/adr/`, `docs/decisions/`), READMEs in touched directories, and any style/architecture guides. These are the source of truth for the docs-compliance pass. List what you found; if there's a `docs/` skeleton or `AGENTS.md`, that's the primary reference.
- **The surrounding code.** Each reviewer will need to read the files *around* the change, not just the diff hunks, to judge coupling and whether an abstraction already exists. Note the touched modules so subagents know where to look.

If the change is large, summarize the shape of it (which subsystems, roughly how many lines, what kind of change — feature/refactor/fix) so each subagent can orient fast.

## Step 2 — Spawn the review passes in parallel

Spawn these as separate subagents **in the same turn** so they run concurrently. Each gets the shared context from Step 1 plus its specific mandate below. Scale the set to the PR: a three-line bugfix doesn't need all five — correctness + maybe docs is enough. A new module or a refactor warrants the full set. Use judgment; don't spawn a design-quality reviewer for a typo fix.

The five mandates live in `references/` so you can hand each subagent its full brief without bloating this file. Read the relevant one(s) when spawning:

1. **Correctness & bugs** → `references/correctness.md`. Logic errors, edge cases, race conditions, error handling, security footguns, broken tests.
2. **Simplification** → `references/simplification.md`. Dead code, over-engineering, redundant abstraction, things the standard library or an existing helper already does, ways to cut lines without losing clarity.
3. **Docs & convention compliance** → `references/docs-compliance.md`. Does the change follow the project's documented conventions and architecture? Where it deviates, is the deviation justified somewhere (PR description, code comment, an ADR)? Unjustified, undocumented deviations are the finding.
4. **Design quality** → `references/design-quality.md`. Coupling, cohesion, abstraction boundaries, SOLID, separation of concerns, and appropriate (not cargo-culted) use of design patterns.
5. **Consistency & API surface** → `references/consistency.md`. Naming, error/return conventions, public-interface changes, backward compatibility. *(Optional — fold into design-quality for smaller PRs.)*

Give each subagent the same output contract: return a list of findings, each with **severity** (blocker / should-fix / nit), **location** (file:line), **what's wrong**, and **a concrete suggested fix or question**. Tell them to return *nothing* for a category rather than padding — an empty correctness report on clean code is a valid, useful result. A reviewer that invents nits to look busy trains the team to ignore the report.

## Step 3 — Synthesize

When the subagents return, merge their findings into one report. This is real work, not concatenation:

- **Deduplicate.** The simplification and design-quality passes will often flag the same tangled function from different angles. Merge into one finding that names both concerns.
- **Resolve conflicts.** Reviewers will sometimes disagree — one wants an abstraction extracted, another flags it as premature. Surface the tension and give your own call as the coordinator, with reasoning. Don't just list both and walk away.
- **Prioritize by severity, then by effort.** Blockers first. Within a tier, lead with high-impact / low-effort fixes.
- **Separate "must" from "might."** The user needs to know what blocks the merge versus what's a judgment call they can decline.

## Output format

Use this structure:

```
## PR Review: <title or branch>

**Verdict:** <Approve / Approve with nits / Request changes / Blocked>
**Scope reviewed:** <N files, what subsystems, base..head>

### 🔴 Blockers
<findings that must be fixed before merge, or "None">

### 🟡 Should fix
<findings worth addressing but not blocking>

### 🔵 Nits & suggestions
<style, minor simplifications, optional improvements>

### 📐 Design notes
<coupling/cohesion/pattern observations that are judgment calls rather than defects — the "here's how I'd think about this" section>

### 📄 Convention compliance
<does it match the docs? list any deviations and whether they're justified>
```

Keep findings concrete and actionable — `file:line — problem — suggested fix`, not vague principles. If everything's clean, say so plainly and don't manufacture concerns. A short honest review builds more trust than a long padded one.

## Notes on judgment

The hard part of code review isn't spotting that two things are coupled — it's knowing when that coupling is *fine*. A `SmsService` that knows about three concrete providers is coupled; wrapping each behind an interface with a failover chain is the textbook fix, but if the project only ever uses one provider and never will, the abstraction is dead weight. Push the reviewers (and yourself) to weigh whether a "violation" actually costs anything *in this codebase*. Flag the principle, but tie it to a real consequence — "this makes provider X impossible to swap for testing" lands; "this violates DIP" doesn't.

Similarly, the docs-compliance pass exists to catch drift, not to enforce dead rules. If the code sensibly deviates from a stale convention, the right finding is often "the docs are out of date," not "the code is wrong." Say which one you think it is.
