# Extraction guide

This is the detail layer for filling out a handoff well. The skill body has the structure; this explains what to mine from the conversation for each section and the traps that produce a useless handoff.

## The core discipline: read the whole conversation

The single biggest cause of bad handoffs is writing from memory of only the recent exchanges. The decisions and dead ends that matter most are usually scattered through the middle of a long session — the failed approach from an hour ago, the constraint the user mentioned once near the start, the reason a library was swapped out. Scan the full conversation before writing. You're an archaeologist, not a stenographer.

## Section-by-section

### Current state
Ask: if the next session ran the project right now, what would they find? What passes, what breaks, what's a stub. Distinguish three buckets clearly: **done and verified**, **done but unverified** (written but not run/tested), and **not started**. The "unverified" bucket is where bugs hide, so call it out — don't let "I wrote it" read as "it works."

### Next steps
Each step should pass the "could a stranger do this?" test. "Finish the API" fails. "Add the `/refresh` endpoint in `routes/auth.ts` mirroring `/login`; it needs the token-rotation helper that's not written yet" passes. Order by what unblocks the most, or by what the user clearly wanted next. If a step is blocked, say *blocked by what* — a blocked step with no reason is a trap the reader springs.

### Errors & dead ends
This is the highest-value, most-skipped section. For each problem worth recording:
- **What was tried** — the approach, concretely.
- **Why it failed** — the actual cause if known, the symptom if not.
- **Resolution or status** — fixed (and how), or still open (and what's been ruled out).

The "what's been ruled out" part is the gold. A handoff that says "tried X, it fails because of Y, so don't bother with that route" saves the next session from re-walking a dead end. Record near-misses too — things that *looked* like solutions but weren't, and why.

Don't record trivial typo-level errors that were fixed in the same breath. Record the ones that cost time or that reveal something non-obvious about the system.

### Decisions made
A decision is anything where an alternative was considered and rejected, or where a non-obvious path was chosen. Capture the choice *and the why*, because the why is what protects it. "Used polling instead of webhooks" invites someone to switch it to webhooks; "Used polling instead of webhooks because the upstream service doesn't support callbacks behind the firewall" closes that loop. If the user made the call, note that — it signals the next session shouldn't override it without asking.

### Files touched
A map, not a diff. The reader can run `git diff` for line-level detail; what they can't easily get is the *intent* — which file does what now, and which are new vs. modified. Group logically. If a lot changed, summarize by area rather than listing every file.

### Original context
Pulled from the start of the conversation and any later clarifications. Capture: the actual ask (in the user's terms), constraints they stated ("must run on the existing cluster", "keep it in MXN", "no new dependencies"), preferences ("they prefer X style"), and any scope boundaries ("explicitly not doing Y this round"). This is reference material — the reader consults it when something upstream is ambiguous, so completeness matters more than brevity here, but it still doesn't need to be a narrative of the whole chat.

## Common failure modes to avoid

- **Transcript-in-disguise**: retelling the conversation chronologically instead of organizing by current state and next action. If your handoff reads like a story with a beginning, you've done it wrong.
- **Burying the lede**: putting original context first. The reader needs the current state first.
- **Vague next steps**: "continue the work", "fix the remaining issues" — actionable to nobody.
- **Silent dead ends**: omitting failed approaches, so the next session cheerfully repeats them.
- **Padding**: inflating thin sections to look thorough. Honest brevity is better; a one-line "current state" for a small task is fine.
- **Lost decisions**: recording *what* was decided but not *why*, so the rationale dies and the decision gets reversed.
