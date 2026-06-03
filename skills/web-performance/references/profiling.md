# Profiling & Measurement

> Never optimize from a guess. The profiler is what turns "the app feels slow" into "WorkspaceView re-rendered 400 times because a prop reference changed on every navigation." Optimizing the wrong layer is wasted effort.

## Pick the right profiler for the question

A JavaScript profiler tells you *a function ran for 12ms*. It cannot tell you *why a component re-rendered*. For React performance problems, those are different questions and you usually need the second one.

- **React DevTools Profiler** — records renders at the component level: what re-rendered, how often, and why (props changed, state changed, parent re-rendered). This is the tool that points straight at re-render bottlenecks. Use it first for any "janky / laggy / freezes on update" symptom.
- **Browser performance profiler** (Chrome DevTools Performance tab) — flame charts for JS execution, layout, paint, and frame timing. Use for scroll jank, long tasks, and animation frame drops.
- **Network tab** — waterfall of requests; reveals serial import chains, blocking requests, double-fetched assets.
- **Lighthouse / Core Web Vitals (LCP, INP, CLS)** — good for first-load and field-style metrics, less so for in-app interaction jank.

## Get a real signal before touching code

1. Reproduce the slow interaction under **realistic load** — not 5 messages but 500, not 10 rows but 10,000, and ideally on a throttled CPU/network. Many bottlenecks only appear at scale.
2. Record with the React DevTools profiler while doing the slow thing once.
3. Read the flamegraph: look for components that re-render when nothing they display changed, and for renders that cascade through many components from a single interaction.
4. Form a specific hypothesis ("navigation produces a fresh `searchParams` reference, so every reader re-renders") before writing a fix.

## Gating the profiler in production builds

It's useful to flip profiling on without shipping it to all users. A common pattern is a flag in `localStorage` that conditionally enables the React profiler build, so you can measure the real production client on demand rather than a dev build that behaves differently.

## Core Web Vitals quick reference

- **LCP (Largest Contentful Paint)** — time until the largest content element renders. Driven by bundle size, render-blocking resources, and server/network latency.
- **INP (Interaction to Next Paint)** — time from an interaction to the next paint. Driven by main-thread work: long tasks, heavy re-renders, expensive event handlers.
- **CLS (Cumulative Layout Shift)** — how much content jumps during load. Driven by un-sized images/fonts, late-injected content, and animating layout properties.

## The discipline

Re-measure after every change. The win you expected may not materialize, and the bottleneck moves after every fix — so the metric you watch this iteration is rarely the one you watch next. Stop optimizing when the app feels right under realistic load, not when a checklist is empty.
