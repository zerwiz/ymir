## hlidskjalf · 2026-11-14 — the window answers while the gate is being asked

### Why

The boot stopwatch measured Hlidskjalf at **9.46 s from window mapped to first answer** while the other halls answered
in a third of a second, and the window was genuinely blank for most of it. Two causes, both measured, not guessed:

1. **`App.tsx` returned `null` until `/api/session` came back** — `if (authed === null) return null;` and
   `if (!session) return null;`. So the window painted nothing at all until a network call answered. Measured on a
   quiet night: 3.4 s; on a busy one: **8.7 s** (a `/api/session` fetch inside the renderer's own resource timings).
   A blank window is not a decision — it is a missing first paint.
2. **Every gate page was a static import.** `Shell.tsx` imported all twenty-one gates (Fleet, Stats, Managandr,
   Snotra, Mail, Skirnir…) so the renderer parsed and executed all of them before the first screen could paint.
   Under this seat's `software` graphics policy (`bin/host/graphics-lib.sh` answers `software`; the Intel iGPU
   beside the A5000 is classified hybrid-fragile) that parse is paid on the CPU, and it is paid before anything is
   visible.

### What changed

| Place | Before | Now |
|---|---|---|
| `src/app/App.tsx` | `return null` while the gate was asked, and again while the session was established | a `Boot` screen — the ember background and *"taking the seat…"* — so the window answers at once; a refusal still shows the gate's own login, and the admitted shell still waits for a real session (no unauthenticated flash) |
| `src/app/Shell.tsx` | 21 static gate imports | each gate is its own chunk, fetched on first open and cached by React (`lazyGate`), inside one `Suspense`; the rail, top bar, stream and mobile nav stay eager because they *are* the first screen |
| `src/styles/shell.css` | — | `.boot-seat`: centred, quiet, `pointer-events: none` — it must read as "the app is here", never as the admitted shell |

Nothing is removed: every gate is the same component, loaded a moment later; the login, the halls chooser, the
stream and the poll all behave exactly as before.

### Proof

`bin/desktop/devtools.cjs perf <port>` (new) reads the renderer's own navigation timings, paint marks, every
resource and the slowest of them. Three cold launches per build, each with its own `--user-data-dir`, measured from
process start to "painted", the renderer asked over its own DevTools port:

| | run 1 | run 2 | run 3 | first paint (renderer) | scripts fetched |
|---|---|---|---|---|---|
| before (the pinned build, `:3888`) | 5070 ms | **13559 ms** | 3178 ms | none / 2536 ms | 1 |
| after (this branch's build, `:3898`) | 2238 ms | 3262 ms | 3299 ms | 972–1492 ms | 1 entry + 4 preloads, gates on demand |

Median **5070 ms → 3262 ms**; the worst case, which is the white window the Allfather saw, **13559 ms → 3299 ms**.
The build now emits the gates as their own chunks (Fleet 6.9 kB, Stats 10.8 kB, Managandr 16 kB …) against a
464 kB entry, where the entry used to carry all of them.

The `/api/session` call is still sometimes slow (8.7 s was seen once, 5–12 ms on three later calls) — the point is
that the window no longer waits for it in the dark.

### Closed after testing

The two measurement windows were launched with their own `--user-data-dir` under `/tmp` and killed after each run;
the `vite preview` on `:3898` was killed; its port and theirs are confirmed closed (`ss`), and `ps` shows nothing of
this test alive. Hlidskjalf's own window, which was open before this work, was left open (and re-raised after a
release flip by another hand closed it).

## CHANGE LOG

- 2026-11-14 — written with the change; three runs per build on this machine.
