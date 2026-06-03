# Data & Network Performance

> The network is the biggest bottleneck you'll ever fight. Any round trip to a server costs hundreds of milliseconds. The best request is the one you never make. The second best is the one the user never waits on.

Symptoms this file addresses: spinners on every save, the app waits on the network for everything, slow even on a fast connection, "loading…" states everywhere.

## The traditional loop is the problem

Most apps live in one loop: user clicks → HTTP request → server queries DB → response → repaint. The result is a spinner, skeleton, or frozen UI for a few hundred ms while the app waits on the network. Every avoided loading state is a win.

```js
// Traditional: UI waits for the server
async function updateIssue({ issue }) {
  showSpinner();
  const res = await fetch(`/api/issues/${issue.id}`, { method: "PATCH", body: JSON.stringify({ title: issue.title }) });
  setIssue(await res.json());
  hideSpinner();
}
```

The key idea: **UI responsiveness must not depend on network latency.** Update the interface immediately; verify in the background.

## Tier 1 (highest leverage): optimistic updates

You don't need a custom sync engine to get most of the benefit. Most mutations succeed, so assume the happy path: update local state now, validate in the background, roll back only if it fails. Libraries like TanStack Query and SWR get you most of the way.

```js
// Optimistic mutation with SWR
mutate(`/api/issues/${issue.id}`, { ...issue, title: "Faster app launch" }, false);
```

The pattern:
- Eliminate the spinner.
- Update state immediately.
- Validate/persist in the background.
- Roll back only if the server rejects (rare — most invalid mutations are caught before the request is even made).

This single change is one of the highest-leverage improvements available to a typical CRUD app.

## Tier 2: local-first / database in the browser

The strongest version eliminates the request entirely. The database the UI reads from lives on the client (IndexedDB, SQLite), and the server becomes a **sync target, not a source of truth for the UI**. There's no "loading issues" state because the issues are already on the machine.

Three pillars — and the speed comes from how they fit together, not any one alone:

1. **The data is already there.** On boot, hydrate from local storage (IndexedDB → in-memory object pool) instead of fetching. Every UI query hits the local pool first.
2. **Mutations don't wait for the network.** A change updates the in-memory store (UI re-renders synchronously), is written to a durable local transaction queue, and is queued for the server — in that order. The network hasn't been touched yet. Retry, rollback, and durability across reloads all happen in the background.
3. **Deltas apply to one cell.** When the server confirms a change (yours or someone else's), it comes back as a small envelope describing what moved, applied to the corresponding granular observable — so one field change re-renders one component, not the whole list (see `references/rendering.md` §4).

Take any pillar away and it feels slow: a local DB without optimistic writes still spins on save; optimistic writes without granular observables still jank on every update; granular observables without a local DB still wait on initial load.

### Data-level code splitting

A local-first store still has to scale. Don't hydrate everything on boot — lazy-hydrate the heaviest tables (e.g. the equivalent of Issue/Comment) on demand. Then startup cost tracks the workspace *structure*, not its *size*: a 10,000-issue workspace boots about as fast as a 100-issue one. This mirrors JS code splitting, applied to data.

### A genuinely local app goes further

If there's no remote DB at all (a desktop app with SQLite as the source of truth), you don't even cache-and-reconcile — the local store *is* the database, and you eliminate an entire category of network-caused performance problems. The trade-off shifts: with the network gone, the next bottleneck is almost always rendering (`references/rendering.md`).

## Auth: render first, verify later

Auth is where many apps spend their performance budget: fetch HTML → load bundle → validate session → fetch user → fetch workspace → render. One to three seconds before anything appears.

Treat auth like a mutation: assume the happy path, verify in the background. If local app state exists, the user has used the app here before and their data is already local — so render it immediately and let the next request (a sync delta, the WebSocket handshake, any HTTP call) be the thing that fails with a 401 if the session went stale, at which point redirect to login.

```js
// The boot question isn't "is the session valid" — it's "do we have anything to show".
if (localStorage.getItem("ApplicationStore") === null) {
  document.documentElement.classList.add("logged-out"); // nothing local → auth layout
}
```

The client trusts what's local; the server is the source of truth for correctness; the two reconcile asynchronously. Same shape as mutations and sync.

## Trade-offs to flag

- Local-first/sync engines add real complexity (conflict resolution, schema migration of the local store, durability). For a small app, optimistic updates with TanStack Query/SWR may be the right stopping point.
- Optimistic UI needs a correct rollback path and clear handling of the rare rejection.
- "Render first, verify later" assumes a stale local view briefly showing is acceptable until the 401 lands — usually fine, occasionally not (e.g. shared machines, sensitive data).
