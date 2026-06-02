---
name: session-handoff
description: Write a structured handoff document that lets a fresh agent session resume work without re-reading the whole conversation. Use when a conversation has grown long, context is filling up, work is being paused, or the user asks to "save progress", "hacer un handoff", "create a handoff", "write a summary to continue later", "document where we are", or otherwise wants the current state captured so work can pick up cleanly in a new session — possibly with a different agent or by a teammate. Trigger this whenever the user signals they want to checkpoint or hand off ongoing work, even if they don't say the word "handoff".
---

# Session Handoff

The purpose of a handoff is narrow and it should drive every choice you make: **a fresh agent, with zero memory of this conversation, should be able to read one file and resume the work competently.** Not "understand what happened" — *resume*. That framing decides what goes in and what stays out. If a detail wouldn't change what the next agent does, it's probably noise.

The failure mode to avoid is a handoff that's just a transcript summary: a flat retelling of the conversation in order. That's nearly useless, because the reader has to reconstruct the *current state* from a story. Instead, lead with where things stand right now, then what to do next, and only then the history as reference. The reader wants "what do I do now?" answered before "what was asked 40 messages ago?".

## Where to write it

Write to `~/.agents/handoff/`. This is a shared, agent-agnostic location so any tool or session can find it. Create the directory if it doesn't exist:

```bash
mkdir -p ~/.agents/handoff
```

Name the file `YYYY-MM-DD_<short-slug>.md`, where the slug is a few words describing the work (e.g. `2026-06-02_intent-classifier-benchmark.md`). The date sorts them chronologically and the slug makes them scannable, so multiple handoffs accumulate without collision. Use the real current date.

Tell the user the full path after writing it.

## Keep it agnostic

Write nothing tied to a specific model, vendor, or agent tool — refer to "the next session" or "whoever resumes this," never a named assistant, so the file reads the same whatever system picks it up. The project's own stack (tools, frameworks, services that are part of the work) is fine and expected; the rule is only about not hard-coding the *agent* that does the reading.

## Document structure

Use this exact section order. The ordering is the point — it front-loads what a cold start needs.

```markdown
# Handoff: <one-line description of the work>
*Written: <date>*

## Current state
Where things stand right now. What's done and working, what's half-done, what hasn't been started. Be concrete: "the X module is implemented and its tests pass; the Y integration is wired but untested; Z is not started." This is the single most important section — if the reader only read this, they should know the lay of the land.

## Next steps
The concrete actions to take, in priority order. Each should be specific enough to act on without guessing — name the file, the function, the command. Mark anything blocked and say what it's blocked on. If there's an obvious "start here," say so.

## Errors & dead ends
What went wrong and what was learned. For each: what was tried, why it failed, and either how it was fixed or — if still open — what's already been ruled out so the next session doesn't repeat it. This section saves the most time and is the easiest to under-write. A dead end that's documented is a dead end nobody walks into twice.

## Decisions made
Choices that were settled during the work and the reasoning behind them (e.g. "chose approach A over B because of constraint C"). Without this, the next session may re-litigate or silently undo a deliberate decision. Keep each to a line or two.

## Files touched
A summary of what changed where — not a diff, a map. Group by file or area: "`path/to/file` — added the parser; `other/file` — refactored to use it." Enough that the reader knows where to look, not a line-by-line account.

## Original context
The background, placed last as reference. What the user originally asked for, key clarifications they made along the way, and any constraints or preferences they stated. The reader comes here to check intent when something in the steps above is ambiguous — they don't need it to start working.
```

## How to fill it well

Read back over the conversation before writing — don't reconstruct from memory of just the last few exchanges, since the important errors and decisions are often buried in the middle. See `references/extraction-guide.md` for what to look for in each section and the common mistakes that make handoffs useless.

Match the length to the work. A handoff for an afternoon's task is one screen; a handoff for a multi-day effort with many dead ends is longer. Don't pad sparse sections to look complete — if no meaningful errors came up, "No significant errors encountered" is a fine and honest entry.

Write in plain prose and tight bullets. Skip ceremony. The reader is an agent trying to get to work, not a stakeholder reading a report.
