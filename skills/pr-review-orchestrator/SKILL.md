---
name: pr-review-orchestrator
description: Orchestrate a multi-agent code review of a pull request or diff. Use when the user asks to review or wants feedback on a PR, MR, diff, branch, or staged/committed changes — e.g. "review this PR", "revisa este PR", "check my changes before I merge", "audit this branch". Spawns specialized subagents that hunt for correctness bugs, look for ways to simplify, check docs/convention compliance, and assess design quality (coupling, cohesion, SOLID).
---

# PR Review Orchestrator

This skill turns you into a **review coordinator**. Given a PR (or any diff/branch), you spawn several specialized subagents in parallel, each with a narrow mandate, then synthesize their findings into a single prioritized report. The point of fanning out is the same reason a good engineering team does multiple review passes: a reviewer hunting for null-pointer bugs is in a different headspace than one judging whether a module is too tightly coupled, and asking one agent to do both at once produces shallow results on both. Separate mandates keep each pass deep. Your job is to route context and merge findings, not to do the reviewing yourself. (If you can't parallelize, run the same passes in serial — the output is identical.)

## Step 0 — Put the PR's code on disk (safely)

Reviewers read the code *around* the change, not just the diff (see Step 1), so the files on disk must be at the **head of the PR**. Review a remote PR while sitting on `main` and the diff is correct but every `Read` of a surrounding file returns the *old* version. Fix this first.

Figure out what's being reviewed and act accordingly:

- **Local pre-merge check (your own staged/committed changes on the current branch).** You're already at the right state — this step is a no-op. Skip to Step 1.
- **A remote or named PR.** Bring its code onto disk **without disturbing the user's working tree**:
  1. Run `git status` first. If there are uncommitted or untracked changes, do **not** checkout over them — a worktree (below) sidesteps this entirely, so prefer it.
  2. Create a throwaway worktree at the PR head so the user's checkout is untouched:
     - With GitHub CLI: ``git worktree add ../review-pr-<n> && (cd ../review-pr-<n> && gh pr checkout <n>)``, or simply `gh pr checkout <n>` if the user explicitly accepts switching their current checkout.
     - Without `gh`: `git fetch origin pull/<n>/head:pr-<n>` (GitHub) / the platform's equivalent refspec, then `git worktree add ../review-pr-<n> pr-<n>`.
  3. **Record the base and head SHAs** (`git rev-parse <base> <head>`) so every reviewer pins to the exact same snapshot.
  4. **Note the worktree path.** Every subagent must read files from there, not from the user's original checkout.
- **No network / can't fetch the PR.** Degrade gracefully: review whatever diff or branch is already available locally, and say in the report that you reviewed the local state rather than the canonical PR head.

**Cleanup.** A worktree you created is temporary. After the review is delivered (Step 3), remove it: `git worktree remove ../review-pr-<n>` (and delete the fetched `pr-<n>` ref if you made one). If anything is uncommitted in it, leave it and tell the user where it is instead of force-removing.

## Step 1 — Gather context once

Before spawning anything, collect the shared material every reviewer needs. Doing this once (rather than letting five subagents each re-run `git diff`) saves time and guarantees they all review the same snapshot.

Collect:
- **The diff.** `git diff <base>...<head>` using the SHAs pinned in Step 0, or the PR's changed files. Default base is the repo's main branch (`main`/`master`) unless the user says otherwise. For a local pre-merge check, `git diff --staged` or `git diff main...HEAD`.
- **The PR description / commit messages.** These state *intent*. A reviewer can't judge whether code matches its purpose without knowing the purpose.
- **The project conventions.** Look for `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `docs/`, ADRs (`docs/adr/`, `docs/decisions/`), READMEs in touched directories, and any style/architecture guides. These are the source of truth for the docs-compliance pass. List what you found; if there's a `docs/` skeleton or `AGENTS.md`, that's the primary reference.
- **The surrounding code.** Each reviewer will need to read the files *around* the change, not just the diff hunks, to judge coupling and whether an abstraction already exists. Note the touched modules so subagents know where to look — and, if Step 0 created a worktree, point them at that path so they read the PR's state, not the stale checkout.

If the change is large, summarize the shape of it (which subsystems, roughly how many lines, what kind of change — feature/refactor/fix) so each subagent can orient fast.

## Step 2 — Spawn the review passes in parallel

Spawn these as separate subagents **in the same turn** so they run concurrently. Each gets the shared context from Step 1 plus its specific mandate below. Scale the set to the PR: a three-line bugfix doesn't need all five — correctness + maybe docs is enough. A new module or a refactor warrants the full set. Use judgment; don't spawn a design-quality reviewer for a typo fix.

The five mandates live in `references/`. Read the relevant one(s) when spawning:

1. **Correctness & bugs** → `references/correctness.md`. Logic errors, edge cases, race conditions, error handling, security footguns, broken tests.
2. **Simplification** → `references/simplification.md`. Dead code, over-engineering, redundant abstraction, things the standard library or an existing helper already does, ways to cut lines without losing clarity.
3. **Docs & convention compliance** → `references/docs-compliance.md`. Does the change follow the project's documented conventions and architecture? Where it deviates, is the deviation justified somewhere (PR description, code comment, an ADR)? Unjustified, undocumented deviations are the finding.
4. **Design quality** → `references/design-quality.md`. Coupling, cohesion, abstraction boundaries, SOLID, separation of concerns, and appropriate (not cargo-culted) use of design patterns.
5. **Consistency & API surface** → `references/consistency.md`. Naming, error/return conventions, public-interface changes, backward compatibility. *(Optional — fold into design-quality for smaller PRs.)*

Give each subagent the same output contract: return a list of findings, each with **severity** (blocker / should-fix / nit), **location** (file:line), **what's wrong**, and **a concrete suggested fix or question**. Tell them to return *nothing* for a category rather than padding — an empty correctness report on clean code is a valid, useful result.

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

The hard part of review isn't spotting coupling — it's knowing when coupling is *fine*. Weigh whether a "violation" actually costs anything *in this codebase*, and tie every flag to a real consequence: "this makes provider X impossible to swap for testing" lands; "this violates DIP" doesn't.

Likewise, docs-compliance catches drift, not dead rules. If the code sensibly deviates from a stale convention, the finding is often "the docs are out of date," not "the code is wrong." Say which.
