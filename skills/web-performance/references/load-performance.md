# Load Performance (First Load & Navigation)

> The network is the bottleneck, so the first lever is always: ship the least code possible, in the smallest pieces, and fetch the rest in the background before the user needs it. For a tool people open daily, the seconds before they can start working matter enormously.

Symptoms this file addresses: slow cold/first load, slow new tab, slow navigation to not-yet-visited views.

## What makes a client-side app slow to load

Request `index.html` → it requests all JS/CSS → run auth → make API requests → finally render. Each step is a chance to add or remove latency. The fix is to attack the chain at build time and at load time.

## 1. Ship less code (build time)

Reducing bytes is the single biggest first-load lever. The biggest wins come from:

- **Drop legacy browser support.** Target modern browsers / native ESM (`target: "esnext"`). No polyfills, no ES5 transpilation, no `nomodule` fallback. This alone can roughly halve first-load JS. (Trade-off: you drop users on old browsers — confirm that's acceptable.)
- **Aggressive dead-code elimination** via a modern bundler (Vite/Rolldown, esbuild). Migrating bundlers isn't the point; the techniques are.
- **Aggressive code splitting** so the entry payload is small and the rest loads on demand.

Real-world result of stacking these (Linear's reported numbers): ~50% less code shipped, ~30% smaller after compression, 10–30% faster cold loads, time-to-first-paint down ~59% on Safari, memory down 70–80%. Note they *still* ship ~21MB minified JS total — the win is that it's split into hundreds of route-level chunks fetched on demand, not one monolith.

## 2. One chunk per dependency (cache granularity)

A single `vendor.js` invalidates the entire dependency graph on any version bump. Splitting each npm package into its own content-hashed chunk makes cache invalidation per-library: bump one dependency, invalidate one chunk, everything else stays cached.

```js
// vite.config.ts — one chunk per npm package
build: {
  target: "esnext",
  cssMinify: "lightningcss",
  modulePreload: { polyfill: false },
  rollupOptions: {
    output: {
      manualChunks(id) {
        if (id.includes("node_modules")) {
          const pkg = id.match(/node_modules\/([^/]+)/)?.[1];
          if (pkg) return `vendor-${pkg}`;
        }
      },
    },
  },
}
```

## 3. Preload to kill the import waterfall (load time)

Splitting into hundreds of chunks creates a new problem: each chunk imports others, and the browser doesn't know what they are until it parses the entry script. Left alone, load becomes a waterfall — fetch entry, parse, fetch its imports, parse, fetch theirs — a round trip per level.

`modulepreload` fixes it. Listing the critical-path chunks in `<head>` lets the browser fire all those requests in parallel before any JS runs, so by the time the entry script hits its first `import`, the chunks are already cached. The waterfall collapses into one parallel batch.

```html
<script type="module" crossorigin src="/assets/html.js"></script>
<link rel="modulepreload" crossorigin href="/assets/vendor-mobx.js">
<link rel="modulepreload" crossorigin href="/assets/SyncWebSocket.js">
<!-- ...the rest of the critical path -->
```

The `crossorigin` attribute must **match** the entry script's, or the browser fetches the resource twice (preload + import treated as separate resources).

- **`modulepreload`** = what the app needs *now*, fetched in parallel.
- **Service worker precache** = what the app needs *next* (route chunks for unvisited views, icons, fonts), pulled down lazily after first load. Within seconds of hitting the login screen, the whole app is in cache — subsequent navigations skip the network entirely and the app works offline.

## 4. Inline the app shell

Eliminate a render-blocking stylesheet fetch by inlining just enough CSS in `<head>` to paint the loading state / shell immediately. Pair it with a tiny inline script that restores remembered shell tokens (sidebar width, theme, logged-in vs logged-out layout) from `localStorage` *before any bundle parses*, so the loading screen is already correctly themed and sized when the user hits enter in the URL bar.

```html
<style>
  :root { --bg-color:#f5f5f5; --sidebar-width:244px; }
  html { background: var(--bg-color); height:100%; }
  #appBorders { margin:8px 8px 8px var(--sidebar-width); border-radius:12px; }
</style>
<script>
  // Restore remembered shell tokens before paint
  const c = JSON.parse(localStorage.getItem("splashScreenConfig") || "{}");
  if (c.sidebarWidth) document.documentElement.style.setProperty("--sidebar-width", c.sidebarWidth + "px");
  if (c.darkMode) document.documentElement.classList.add("dark");
  // No local store → render the auth layout
  if (localStorage.getItem("ApplicationStore") === null) document.documentElement.classList.add("logged-out");
</script>
```

(The "render first, verify auth later" pattern lives in `references/data-and-network.md`.)

## 5. Fonts — the three failure modes

Apps commonly get fonts wrong in three visible ways: invisible text for half a second, layout shift as the real font swaps in, and double-fetched font files. Fix all three:

```html
<link rel="preconnect" href="https://static.example.com" crossorigin>
<link rel="preload" href="/fonts/InterVariable.woff2" as="font" type="font/woff2" crossorigin="anonymous">
```
```css
@font-face {
  font-family: "Inter Variable";
  font-weight: 100 900;       /* variable font: full weight axis in ONE woff2 */
  font-display: swap;         /* paint fallback immediately, swap when loaded */
  src: url(/fonts/InterVariable.woff2) format("woff2");
}
```

- **Variable font** covers the whole weight range in a single file — no per-weight requests.
- **`font-display: swap`** renders the fallback immediately, then swaps — no invisible text.
- **`crossorigin="anonymous"` on the preload** must match how the CSS fetches it, or the browser downloads the font twice (preload and CSS reference have different CORS modes).

## 6. Lazy-load below-the-fold work

Rule of thumb: if a feature isn't visible on initial load, it shouldn't block rendering. `React.lazy` + `Suspense` (or route-level dynamic imports) defer it. Optimize images on upload (WebP/AVIF, thumbnails, sized to prevent CLS) rather than shipping originals.

## Quick checklist

- Target modern browsers / ESM; drop legacy polyfills (if acceptable).
- Code-split aggressively; one content-hashed chunk per dependency.
- `modulepreload` the critical-path chunks; `crossorigin` must match the entry.
- Service worker to precache the rest in the background → instant navigation + offline.
- Inline the app shell CSS and the shell-token restore script.
- Variable fonts, `font-display: swap`, matched `crossorigin` on preload.
- Lazy-load anything not needed for first paint.
