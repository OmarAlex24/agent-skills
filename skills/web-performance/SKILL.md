---
name: web-performance
description: Diagnose and fix performance problems in web and desktop apps (React, Vite/bundlers, Electron/Tauri, local-first sync). Use this whenever the user mentions an app feeling slow, janky scrolling, laggy typing/input, slow initial load, slow navigation, excessive re-renders, large bundles, slow chat/list rendering, high memory usage, or asks "why is my app slow" / "how do I make X fast" / "how is Linear/Conductor so fast". Also trigger for profiling setup, virtualization of long lists, optimistic updates, code splitting, font/asset loading, and animation performance — even if the user doesn't say the word "performance".
---

# Web Performance Optimization

A diagnostic-first playbook for making web and desktop apps feel fast, distilled from how teams like Linear and Conductor built genuinely fast products. The throughline across all of it: **the network is the enemy, and the bottleneck never disappears — it only moves.** Every fix exposes the next slowest thing, so the work is iterative and measurement-driven, not a one-time checklist.

## Core mental model

Internalize these before touching code. They decide which fix actually matters.

1. **Measure first, always.** Never optimize from a guess. A profiler tells you the slow part is React re-rendering 400 times, not the data layer you assumed. Optimizing the wrong layer wastes effort and can make things worse. If there's no measurement yet, setting up profiling *is* the first task.

2. **The bottleneck moves.** Remove the biggest one (usually the network) and the next one (re-renders, then scroll jank, then dropped frames) comes into focus. Expect to iterate. A "fast app" is hundreds of correct decisions, not one silver bullet.

3. **Perceived speed > actual speed.** Users judge by how fast the *interface reacts*, not how fast the server responds. Updating the UI immediately and reconciling in the background beats a correct-but-blocking flow every time.

4. **Eliminate work, don't just speed it up.** The fastest operation is the one the user never waits on. Prefer removing a network request, a re-render, or a synchronous step over making it faster.

5. **Reach for the right tool, don't paper over the problem.** When you hit a re-render storm, fixing the underlying unstable reference (e.g. router-level structural sharing) beats sprinkling `useMemo` across fifty components. Picking the library/primitive that solves the *actual* problem is its own kind of simplicity.

## Workflow

Follow this loop. Don't skip straight to fixes.

### 1. Characterize the symptom
Pin down *what* feels slow and *when*. The category points to the reference file you'll need:

| Symptom | Likely cause | Read |
| --- | --- | --- |
| Slow first/cold load, slow new tab | Bundle size, waterfall imports, blocking auth, font/asset loading | `references/load-performance.md` |
| Janky scroll, laggy typing, slow navigation, UI freezes on update | Excessive/cascading re-renders, no virtualization, unstable refs | `references/rendering.md` |
| Spinners on every save, app waits on network, slow even on fast connection | No local-first/optimistic data layer | `references/data-and-network.md` |
| Slow desktop app, high memory, slow cold start | Electron/Tauri shell choices, runtime, subprocess management, profiling gaps | `references/desktop-apps.md` |
| Animations feel sluggish or janky | Animating layout-triggering properties, durations too long | `references/animations.md` |
| "It's just slow everywhere" / don't know | Start with profiling | `references/profiling.md` |

Most real investigations touch more than one file — load + rendering is the most common pair. Read every reference that plausibly applies; they're short.

### 2. Set up measurement
If the user has no profiler data, go to `references/profiling.md` first and get a real signal. For React, the React DevTools profiler (what re-rendered and why) is usually more diagnostic than a raw JS profiler. For desktop apps in a non-Chromium webview (Tauri/WKWebView), see the bridge-shim trick in `references/desktop-apps.md` to get the real client into Chrome where DevTools work.

### 3. Apply the highest-leverage fix
Order of leverage, roughly: eliminate network requests → fix cascading re-renders at the source → virtualize unbounded lists → trim & split the bundle → fix asset loading → tighten animations. Do the biggest one, then **re-measure** — the bottleneck has moved.

### 4. Re-measure and repeat
Confirm the fix moved the metric, then characterize the new slowest thing. Stop when the app feels right under realistic load (hundreds of messages streaming, thousands of rows, slow connection), not when the checklist is empty.

## When writing or editing code

- Match the user's existing stack and conventions. These references describe techniques, not a mandated stack — Linear thrives on a deliberately plain stack (React + MobX + Postgres, no meta-framework), Conductor leans all-in on TanStack + Tauri. Both are fast. Don't impose one shape.
- Prefer fixing root causes (unstable references, missing virtualization, blocking network calls) over scattering memoization.
- Keep changes scoped and measurable: one lever at a time so you can attribute the win.
- Note the trade-offs of any architectural suggestion (local-first adds sync complexity; virtualization complicates find-in-page; dropping legacy browser support drops users on old browsers).

## A note on humility

These patterns come from studying how specific teams made specific apps fast; they're strong defaults, not laws. The hard part was never the libraries — you can learn TanStack Router in a weekend. The hard part is living in the product long enough to feel every dropped frame and caring enough to chase each one down. Help the user build that measurement-and-iteration habit, not just ship one fix.
