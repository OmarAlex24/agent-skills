# agent-skills

My versioned [agent skills](https://agentskills.io), built to work together as a
**plan → build → review → hand off** loop for coding work. Each skill is a focused
instruction set your agent loads on demand; this README is about *what they do and
when to reach for them*. Installation is at the [bottom](#installing).

## The skills

### `session-handoff`

Writes a structured handoff document so a fresh agent session (or a teammate) can
resume work without re-reading the whole conversation. It front-loads *current state*
and *next steps*, then records errors/dead-ends, decisions, files touched, and the
original context as reference.

**Reach for it when:**
- A conversation has grown long and context is filling up.
- You're pausing work for the day and want a clean restart later.
- You're switching agents/tools and need the state captured agent-agnostically.
- You say things like "save progress", "hacer un handoff", "document where we are".

**Why it helps:** the next session reads one file and *resumes* competently, instead
of reconstructing the state from a transcript. Dead ends are recorded so nobody walks
into them twice.

### `delegate-implementation`

After a plan is agreed on, hands the actual implementation to an external coding-agent
CLI (Codex) running non-interactively, waits for it to finish, then reviews the diff it
produced. Your session stays the **architect + reviewer**; the external agent is the
**implementer**.

**Reach for it when:**
- You've finished planning and want the code built by a separate agent in its own context.
- You want to keep the judgment-heavy parts (planning, review) in this session and
  offload the mechanical typing.
- You say "delegate this to codex", "pásale esto a codex", "let another agent build it".

**Why it helps:** `codex exec` is synchronous — it runs to completion and the changes
land in your working tree. The skill captures a git base ref first so the review can
isolate exactly what the external agent changed, then reviews against the original plan.

> Requires `codex` installed and authenticated, inside a git repo.

### `pr-review-orchestrator`

Coordinates a multi-agent code review of a PR, branch, or diff. It spawns specialized
review passes in parallel — correctness/bugs, simplification, docs & convention
compliance, design quality, consistency/API surface — then synthesizes them into one
prioritized verdict (blockers / should-fix / nits).

**Reach for it when:**
- You're about to merge and want a thorough pre-merge check.
- You want deeper review than a single pass — separate mandates keep each pass deep.
- You say "review this PR", "revisa este PR", "check my changes before I merge".

**Why it helps:** a reviewer hunting null-pointer bugs is in a different headspace than
one judging coupling; fanning out and merging the results catches more than one
generalist pass. It also flags *unjustified* deviations from your project's docs, not
just any deviation.

### `web-performance`

Diagnoses and fixes performance problems in web and desktop apps. Covers load
performance, rendering bottlenecks, data & network latency, animation jank, and desktop
shell profiling — all measurement-first and stack-agnostic.

**Reach for it when:**
- The app feels slow, janky, or laggy — on scroll, typing, navigation, or first load.
- You're fighting large bundles, excessive re-renders, or slow list/chat rendering.
- You say "why is my app slow", "how do I make X fast", or need profiling setup.

**Why it helps:** it replaces guess-and-check with a diagnostic loop: characterize the
symptom, measure with the right profiler, apply the highest-leverage fix, then
re-measure. The references cover everything from `modulepreload` and code splitting to
virtualization, optimistic updates, and the Tauri profiling bridge shim.

## How they fit together

```
        plan (this session)
              │
              ▼
   delegate-implementation ──► external agent writes the code
              │
              ▼
   pr-review-orchestrator ───► reviews the resulting diff
              │
              ▼
       session-handoff ──────► checkpoint state for the next session
```

`delegate-implementation` calls `pr-review-orchestrator` for its review step, and any
of them can be used standalone — you don't need the whole loop to get value from one.

## Example scenarios

- **Long feature session running out of context** → run `session-handoff`, start a
  fresh session, keep going from the handoff file.
- **Plan approved, want it built fast** → `delegate-implementation` hands it to Codex,
  then auto-reviews the diff with `pr-review-orchestrator`; you accept or request changes.
- **Reviewing a teammate's PR before merge** → `pr-review-orchestrator` gives you a
  verdict with blockers separated from nits and design notes.
- **Wrapping up for the day mid-refactor** → `session-handoff` records what's done,
  what's half-wired, and the dead ends you already ruled out.
- **App feels janky or loads too slowly** → `web-performance` profiles the symptom,
  identifies the bottleneck (re-renders, bundle size, missing virtualization), and
  applies the fix with before/after measurements.

## Installing

Skills are installed with the Vercel [`npx skills`](https://github.com/vercel-labs/skills)
CLI. Versioning is tracked via git — each commit/tag of this repo is a release.

```bash
# All skills
npx skills add OmarAlex24/agent-skills

# A single skill
npx skills add OmarAlex24/agent-skills --skill session-handoff

# List without installing
npx skills add OmarAlex24/agent-skills --list

# Global instead of per-project
npx skills add OmarAlex24/agent-skills -g

# Update later
npx skills update
```

## Repo layout

```
skills/<name>/
├── SKILL.md          # required: frontmatter (name, description) + instructions
├── references/       # optional: detail loaded on demand
└── scripts/          # optional: executable code
```

`npx skills` discovers any `skills/<name>/SKILL.md`; the frontmatter `name` must match
the folder name. `scripts/validate.sh` enforces this and runs in CI on every push/PR.
To add a new skill: `npx skills init skills/<name>`, then follow the
[spec](https://agentskills.io/specification).
