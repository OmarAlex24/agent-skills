---
name: delegate-implementation
description: After a plan is agreed on, delegate the actual implementation to an external coding-agent CLI (Codex) running non-interactively, wait for it to finish, then review the work it produced. Use when the user has approved or finished a plan and wants it built by a different agent rather than implemented in this session — phrasings like "delegate this to codex", "have codex implement this", "pásale esto a codex", "let another agent build it", "implement the plan with codex", or when leaving plan mode with an instruction to hand the work off. In the plan-then-delegate-then-review loop, this session plans and reviews while the external agent implements. Trigger this whenever the user wants the agreed plan handed to an external agent to write the code.
---

# Delegate Implementation

This skill runs a three-role loop where **this session is the architect and reviewer, and an external agent (Codex) is the implementer**. You plan, Codex builds, you review. The point is to keep planning and reviewing — the judgment-heavy parts — in this session, while offloading the mechanical implementation to a separate agent that works in its own context.

The whole thing rests on one fact that makes it robust rather than fragile: **`codex exec` is synchronous.** It runs a single session to completion and exits when the task is done. There is no watcher, no polling, no "wake up when it's finished" — you run the command, it blocks, and when control returns to you the work is done and sitting in the working tree. Build the skill around that and it stays simple.

## Prerequisites — check before delegating

Confirm the external agent is available and authenticated before building a prompt, so you fail fast with a clear message instead of mid-flow:

```bash
command -v codex >/dev/null 2>&1 && codex login status
```

If `codex` isn't installed (`npm install -g @openai/codex`) or `codex login status` exits non-zero, stop and tell the user how to fix it rather than proceeding. Also confirm you're inside a git repo with a clean-enough working tree to tell apart what Codex changes — that's how the review step works.

## The loop

### 1. Have a plan worth delegating

This skill begins *after* a plan exists — usually because the user worked one out in this session (e.g. left plan mode) or stated one directly. Don't delegate a vague intention; the external agent works in a fresh context with none of this conversation's history, so the plan you hand it is essentially all it knows. If the plan is thin, tighten it first: what to build, which files/modules are in scope, the conventions to follow, and what "done" looks like. A good plan in equals usable code out; a vague plan equals a wasted run.

### 2. Capture the starting point

Before delegating, record where the tree stands so you can isolate exactly what the external agent changed:

```bash
git rev-parse HEAD > /tmp/delegate-base-ref.txt   # commit to diff against later
git status --porcelain                             # note any pre-existing dirty files
```

If the tree is already dirty, note which files were dirty *before* so the review doesn't blame Codex for them. Cleanest is to delegate from a clean tree or a dedicated branch.

### 3. Build the delegation prompt and hand it off

Write the full plan to a file, then pipe it into `codex exec` via stdin. Piping (rather than passing as an argument) avoids shell-escaping pain with long, multi-line plans. The helper `scripts/delegate.sh` wraps the recommended invocation; read it before first use so you understand the flags. The core call it makes:

```bash
codex exec - \
  --cd "$REPO_ROOT" \
  --sandbox workspace-write \
  --ask-for-approval never \
  --json \
  --output-last-message /tmp/delegate-result.txt \
  < /tmp/delegate-prompt.md \
  | tee /tmp/delegate-events.jsonl
```

Why these flags:
- `codex exec -` reads the prompt from stdin (the `-` forces it explicitly).
- `--cd "$REPO_ROOT"` pins the working directory so Codex edits the right repo.
- `--sandbox workspace-write` lets it read, edit, and run commands **inside the workspace** without asking — the right level for unattended implementation. It still can't touch things outside the workspace. Use `--add-dir <path>` to grant extra directories rather than escalating the whole sandbox. Avoid the `--yolo` / full-access mode unless you're in a throwaway environment; it removes the guardrails.
- `--ask-for-approval never` is what keeps it from hanging. In non-interactive mode any approval request would otherwise fail the run; `never` means it proceeds without pausing for a human. (`--full-auto` is deprecated in favor of the explicit sandbox flag above.)
- `--json` streams newline-delimited events so you can tell what happened; `--output-last-message` captures Codex's final summary in a file you'll read in the review step.

This command **blocks** until Codex is done. That's the "wait" — you don't manage it, the shell does. When it returns, check the exit code: non-zero means Codex hit an error or couldn't finish, and you should read the events/summary and tell the user rather than reviewing a half-done change.

The prompt you write to `/tmp/delegate-prompt.md` should give the external agent everything it needs cold: the goal, the concrete steps, the in-scope files, the project conventions (point it at `AGENTS.md` / `docs/` if they exist), constraints, and a clear definition of done. See `references/prompt-construction.md` for what makes a delegation prompt that produces usable code.

### 4. See what changed

When the command returns, the changes are in the working tree. Reconstruct exactly what Codex did:

```bash
git diff "$(cat /tmp/delegate-base-ref.txt)"          # all changes since the base
git diff --stat "$(cat /tmp/delegate-base-ref.txt)"   # the file-level map
cat /tmp/delegate-result.txt                          # Codex's own summary of what it did
```

Read Codex's summary, but **don't trust it as the review** — it's the implementer describing its own work. The diff is ground truth.

### 5. Review the work — reuse the PR review skill

This is where this session earns its keep as the reviewer. Don't hand-wave the review. Invoke the **`pr-review-orchestrator`** skill on the diff produced in step 4 — it already knows how to fan out across correctness, simplification, docs-compliance, and design quality, and synthesize a verdict. Treat the base ref from step 2 as the review base. The handoff is natural: that skill is built to review "a diff/branch versus a base," which is exactly what you have.

If `pr-review-orchestrator` isn't installed, fall back to a direct review of the diff against the original plan: did it do what the plan said, is it correct, does it follow the project's conventions, did it over-build? But prefer the dedicated skill.

### 6. Decide and iterate

Based on the review, choose with the user:
- **Accept** — the work is good; commit it (or let the user do so).
- **Request changes** — feed the review findings back to the same Codex session so it fixes its own work, preserving its context:
  ```bash
  codex exec resume --last --cd "$REPO_ROOT" --sandbox workspace-write --ask-for-approval never -
  ```
  Pipe the specific findings in as the follow-up prompt, then return to step 4 and re-review. `resume --last` continues the most recent session from this directory.
- **Take it over** — if Codex is going in circles on something subtle, pull the work back into this session and finish it directly. Delegation is a tool, not a contract; bail when it stops paying off.

## Staying agent-agnostic

The loop — plan, capture base, delegate non-interactively, diff, review, iterate — is independent of which external agent implements. Codex is the first target, but the same shape works with any agent that has a non-interactive "run a prompt to completion" mode and edits the working tree in place. If you later wire in another, the only things that change are the command and its flags; the surrounding logic (git base capture, diff, review via `pr-review-orchestrator`) stays identical. Keep that separation in mind so the skill doesn't get welded to one vendor.

## Common failure modes

- **Hanging forever**: almost always a missing `--ask-for-approval never` (or sandbox set so tight Codex needs approval for everything). The run should never wait on human input.
- **Codex edits the wrong repo**: missing or wrong `--cd`. Always pin it.
- **Review blames Codex for pre-existing changes**: tree was dirty before delegating and you diffed against the wrong base. Capture the base ref first; delegate from a clean tree when you can.
- **Vague plan, sprawling diff**: the prompt didn't scope the work. Tighten the plan before re-running, don't try to salvage a bad run by reviewing harder.
- **Trusting the summary over the diff**: always review the actual changes, not Codex's description of them.
