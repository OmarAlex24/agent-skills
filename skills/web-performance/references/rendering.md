# Rendering Performance (React)

> Once the network is out of the way, every unnecessary re-render, janky scroll, and dropped frame becomes the slowest thing the user feels. Most "the app is laggy" problems live here.

Symptoms this file addresses: laggy typing, janky scroll, slow navigation between views, UI freezing when data updates, slow chat/list rendering.

## 1. Cascading re-renders from unstable references

The classic React bottleneck. An app with several heavy views mounted at once (sidebar, nav, chat, terminal, editor) is brutal here: one unstable reference at the top cascades a re-render through every mounted pane.

**The trap — fresh references every render.** APIs that return a new object/array each render force every consumer to re-render even when nothing actually changed:

```js
// react-router: useSearchParams() returns a NEW object every render,
// and this derived object is new every render too.
const [searchParams] = useSearchParams();
const filters = { agent: searchParams.get("agent"), status: searchParams.get("status") };

useEffect(() => { refetchAgents(filters); }, [filters]); // fires on EVERY render
return <AgentList filters={filters} />;                   // child re-renders every time
```

**The weak fix — hand-rolled memoization.** You can stabilize with `useMemo`, but doing it across many components is tedious and error-prone; you inevitably miss a dependency or hit an edge case:

```js
const filters = useMemo(() => ({ agent, status }), [agent, status]); // fragile at scale
```

**The real fix — stable references at the source.** Fix the thing producing the unstable reference instead of patching every consumer. For routing, a router with *structural sharing* returns the same reference unless a value actually changes (e.g. TanStack Router's `Route.useSearch()`), so navigation no longer cascades:

```js
const filters = Route.useSearch(); // SAME ref unless agent/status really change
useEffect(() => { refetchAgents(filters); }, [filters]); // fires only on real change
return <AgentList filters={filters} />;                   // no re-render
```

Principle: when you hit a re-render storm, find the unstable reference at its origin rather than spraying `useMemo` across fifty components.

## 2. Virtualize unbounded lists

Any list that grows without bound — chat history, issue lists, logs, tables — must be virtualized. Rendering 500 rows into the DOM at once freezes the UI; rendering only the ~15 in the viewport (plus a small buffer) keeps it smooth.

```jsx
// Before: every item in the DOM, all re-render on any change
{messages.map((m) => <Message key={m.id} message={m} />)}

// After: virtualized list + memoized rows
const Message = React.memo(function Message({ message }) {
  return <MarkdownContent text={message.content} />;
});
// react-virtuoso renders only what's on screen
<VirtuosoMessageList data={messages} itemContent={(_, m) => <Message message={m} />} />
```

Use a library suited to the surface (`react-virtuoso` / `VirtuosoMessageList` for chat, `@tanstack/react-virtual` for general lists/grids). For chat specifically, a purpose-built component handles the miserable parts for you: sticking to the bottom as messages arrive, anchoring scroll position when older content loads at the top, and smoothly re-measuring a message that grows as it streams. Hand-rolling that scroll math is where chat UIs go to die.

## 3. Streaming content: render only what changed

Chat is one of the hardest things to make fast because three forces compound:
- The list grows without bound (hundreds of markdown + syntax-highlighted messages).
- The content streams — the last message grows one token at a time, and every token is a state update.
- Re-renders cascade — if a token update touches the array holding all messages, React reconciles all of them, re-parsing markdown and re-highlighting code for messages that didn't change.

Fix: combine virtualization (above) with `React.memo` and stable keys so a token landing in the streaming message re-renders **that one message** and leaves the other 499 untouched.

## 4. Granular, atomic updates (avoid cascades by design)

The deepest version of this is architectural: make each piece of state its own observable so a change re-renders exactly the components that read that field — one cell, not the whole list.

This is how Linear stays smooth with ten people editing at once: every property on every model is its own observable, and every component that reads one is wrapped in `observer()`. A 50-issue update is 50 cell re-renders, not one list re-render. The cost of receiving updates scales with *what changed*, not *what's on screen*. MobX makes this natural; Zustand with narrow selectors and `React.memo` can approximate it. The goal is the same regardless of library: avoid cascading updates.

## 5. React Compiler (React 19+)

The React Compiler (React 19.2+) auto-memoizes and reduces the need for manual `useMemo`/`React.memo`/`useCallback`. It lowers the floor — juniors write reasonably performant code by default — but it does **not** fix bad component design, unstable references coming from outside React (router, context), or inefficient data fetching. You can't compile your way out of an architectural problem. Treat it as a helpful default, not a substitute for the fixes above.

## Quick checklist

- Profile with React DevTools before changing anything (`references/profiling.md`).
- Hunt for unstable references at the source (router, context, derived objects) before reaching for `useMemo`.
- Virtualize any list that can grow unbounded.
- `React.memo` + stable keys so streaming/single-item updates don't re-render siblings.
- Keep global state narrow; prefer granular selectors/observables over broad context that re-renders wide subtrees.
- Avoid anonymous functions/objects passed as props on hot paths when they break memoization.
