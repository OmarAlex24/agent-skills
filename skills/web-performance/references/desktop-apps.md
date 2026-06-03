# Desktop App Performance (Electron / Tauri)

> Desktop apps inherit every web performance concern plus a few of their own: which native shell, which runtime, how to profile a non-Chromium webview, and how to manage heavyweight subprocesses. The shell choice is an architecture-fit decision, not a simple speed contest.

Symptoms this file addresses: slow desktop app, large bundle, slow cold start, high memory with many windows/processes, "I can't profile this."

## Electron vs Tauri: fit, not a speed contest

The debate is usually framed as performance, but in practice the deciding factor is **architecture fit**:

- **Tauri** — Rust shell + the OS's native webview (WKWebView/Safari on macOS, WebView2 on Windows). Smaller bundle, faster cold start, snappier UI rendering. Fits an architecture where a Rust core spawns and supervises native processes and the UI is "just" a web app talking to it over a bridge.
- **Electron** — ships its own Chromium. Bigger bundle, but you inherit Chrome's entire toolchain for free (Performance profiler, memory tools, **React DevTools extension**) and a TypeScript client-server design fits Node's runtime naturally.

Real teams move in *both* directions for sound reasons: a Rust-core + agent-CLI architecture picks Tauri for the small bundle and fast start; a TypeScript client-server app that dropped its Bun dependencies moves *to* Electron because Node fit better. Recommend based on the app's architecture, not a benchmark.

## The Tauri profiling gap (and the fix)

Tauri's biggest hidden cost: it renders in the OS webview, so on macOS you only get Safari's Web Inspector. That has a JS profiler but **not** React DevTools — and the React DevTools browser extension can't load inside WKWebView at all. So the one tool that points straight at a React bottleneck is the one you can't run.

The fix exploits the fact that the frontend is just a Vite SPA — nothing about rendering a message or a file tree needs the native shell. The UI only touches native code through the bridge (Tauri's `invoke()`). Shim that one entry point and the *exact same production client* boots in plain Chrome, where both the Chrome profiler and React DevTools work:

```js
import { invoke as tauriInvoke } from "@tauri-apps/api/core";

export function invoke<T>(cmd: string, args?: Record<string, unknown>): Promise<T> {
  // Packaged app: use the real native bridge.
  if ("__TAURI_INTERNALS__" in window) return tauriInvoke<T>(cmd, args);

  // Dev in Chrome: stand in for the Rust backend — proxy to a dev server
  // running the real commands, or return canned data for the surface you're profiling.
  return fetch(`/__backend__/${cmd}`, { method: "POST", body: JSON.stringify(args ?? {}) })
    .then((r) => r.json());
}
```

With the bridge shimmed, profile the real client in Chrome and the bottlenecks stop being a guess.

## Runtime choice for bundled processes

If the app spawns sidecar processes (agents, language servers, workers), the runtime matters for both bundle size and start latency. Switching a sidecar runtime from Node to **Bun** can cut a meaningful chunk off the bundle (e.g. ~150MB) and shave time off process spin-up/resume — which directly helps any path where the user waits on a process starting.

## Manage heavyweight subprocesses as a feature

An app that runs several long-lived processes (each holding a model session, file watchers, memory) can't keep them all alive forever. Treat memory management as a feature, not an afterthought:

- **Reclaim idle processes.** Shut down a process that's been idle and reclaim its memory.
- **Make shutdown lossless.** Make it safe to kill by persisting session state to disk and resuming on demand (e.g. launch every session with a `--resume <uuid>` flag so a killed process loses nothing and resumes when the user returns).

Ten open workspaces shouldn't mean ten permanently live processes.

## Get out of the way of the first response

Whatever the app's core "go" action is (first model token, first frame, first result), nothing local should sit between the user and it. Audit the critical path for synchronous work hiding there.

Example: an agent run that begins with a *synchronous* checkpoint — `git add -A` walks the entire repo to stage it — puts that walk right between the user and the first token. The fix is to move it **off the critical path**: fire the snapshot in the background and let the agent respond immediately. You still get the rollback point; it just no longer makes the user wait. A faster-starting runtime helps the same path when a process must spin up. The fastest operation is the one the user never waits on.

## Quick checklist

- Recommend Electron vs Tauri by architecture fit, not raw benchmark.
- On Tauri/non-Chromium webviews, shim the native bridge to profile the real client in Chrome with React DevTools.
- Consider Bun over Node for bundled sidecar processes (smaller bundle, faster start).
- Reclaim idle subprocesses; persist + resume so shutdown is lossless.
- Move synchronous work off the critical path to the user's primary action.
- Everything in `references/load-performance.md` and `references/rendering.md` still applies inside the webview.
