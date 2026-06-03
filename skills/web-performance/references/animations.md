# Animation Performance

> All the work to make an app fast can be undone in the last step by one bad animation. A team shaves milliseconds off load, queries, and updates — then adds a 500ms height animation and the app feels slow again.

Symptoms this file addresses: sluggish or janky animations, hover/transition lag, scroll jank that correlates with animated elements.

## Only animate the cheap properties

Browsers have three tiers of property changes; cost scales with how high the property sits in the rendering pipeline:

| Tier | Properties | Cost |
| --- | --- | --- |
| **Composited** (cheap) | `transform`, `opacity` | Handed to the GPU, runs off the main thread. Animate freely. |
| **Paint** (medium) | `color`, `background-color`, `border-color`, `fill` | Skips layout but redraws pixels. Fine in moderation. |
| **Layout** (expensive) | `width`, `height`, `top`, `left`, `margin`, `padding` | Forces recomputing the position of every subsequent element, every frame. **Never animate these.** |

```css
/* Good — composited + a cheap paint property */
.row:hover { background-color: var(--color-bg-hover); transition: background-color 0.12s; }
.icon-arrow { transform: translateX(0); transition: transform 0.15s; }

/* Bad — animating layout recomputes every row beneath, every frame */
.row:hover { margin-left: 2px; transition: all 0.2s; }
```

The `margin-left` version re-lays-out every row below the hovered one on every frame for the full transition. On a long list that's the difference between buttery and janky. `transition: all` is a trap — it sweeps up whatever property changes, including layout ones.

## Keep durations short and snappy

Most design systems default longer than they should (Material ~200ms, iOS spring ~350ms). Shorter transitions are one of the easiest ways to make an app feel faster. A snappy scale, roughly:

```css
--speed-highlightFadeIn: 0s;
--speed-highlightFadeOut: 0.15s;
--speed-quickTransition: 0.1s;
--speed-regularTransition: 0.25s;
--speed-slowTransition: 0.35s;
```

Stay below the ~100ms cause-and-effect threshold for the things that should feel instant. Consider **asymmetric timing**: appear instantly when summoned, fade out over ~150ms when dismissed (matches how native UIs feel).

## Make motion do spatial work, or cut it

Good animations reference their origin — a popover scales out of the pill that opened it, a panel slides in from its toggle. The motion tells the user *where the element came from* instead of fading in from nowhere as decoration.

And know when **not** to animate. In a tool used all day, animations you'd love on a marketing site get in the way; even a small hover delay in the wrong place becomes the thing the user notices. List items in a productivity app often have no transitions at all, on purpose. Reserve animation for where it communicates something.

## Quick checklist

- Animate `transform` / `opacity` by default; `background-color` / `border-color` sparingly.
- Never animate `width`, `height`, `top`, `left`, `margin`, `padding`. Never use `transition: all`.
- Default durations short (~100–250ms); consider asymmetric enter/exit.
- Motion should reference an origin or be removed.
