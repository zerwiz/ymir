# hlidskjalf · 2026-11-14 — the Health view reads the leak ledger for a person

**Component:** hlidskjalf · **Branch:** `eindri/leak-health-view` (plan 286, phase P6)
**Files:** `apps/hlidskjalf/server/health.ts` (new), `apps/hlidskjalf/server/health.test.ts` (new),
`apps/hlidskjalf/server/index.ts` (`/api/soak`), `apps/hlidskjalf/src/components/SoakHealth.tsx` (new),
`apps/hlidskjalf/src/gates/Runtime.tsx`, `apps/hlidskjalf/src/services/api.ts`,
`docs/features/the-health-view.md` (new), `docs/features/hlidskjalf-the-control-plane.md`,
`.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md`

## Why

Plan 286 measures the house two ways, and at 2026-11-14 neither answer was on a screen.
The leak ledger (`bin/ward/soak-sampler.sh`) had already written 563 rows for 33 services in an
hour, and the soak harness (`bin/gates/soak.sh`) was raising and driving apps, but the only way
to read any of it was `tail` on a JSONL file — raw text, one row per line, for a person who must
answer *"is the house whole?"* in a glance. RULES/52 says a person never reads TOON and never
reads a machine's raw rows on a page.

P6 of the plan: **a Health view on the Runtime page draws each app's last soak and each service's
trend, with the budgets of §5, and a plain verdict per row.**

## What changed

**The gate reads the ledger once, and judges it in one place.** `server/health.ts` (new) reads
`$YMIR_HOME/state/soak/services/<date>.jsonl` and `$YMIR_HOME/state/soak/<app>/<date>.jsonl` and
hands back one `SoakHealth`: the budgets, the newest pass and its age, and a verdict per row.

- **Services** — the ledger's own last window (30 min ending at the newest pass, not at *now*),
  so a stopped sampler still shows the last true trend. Per service: RSS now and its growth,
  file descriptors, inotify watches, children, zombies, GPU, restarts now and inside the window.
  The restart count sums **positive** steps, because systemd resets `NRestarts` when a unit stops;
  a storm row from the ward is the verdict even when the count is low.
- **Apps** — the LAST RUN of each app's soak, read in the soak harness's own shape
  (`raise · boot · baseline · cycle · after_cycles · sample · judge · finding · skip`). The
  harness's `judge` row **is** plan 286 §5 already applied, so its word is the verdict: `pass`
  holds, `leak` grows, and the `finding` rows say why **in the harness's own words**. A run still
  being written is `unknown` with its numbers shown; a run that reached after-cycles with no judge
  row is judged here against §5 and the row says `unjudged` — the page never pretends the harness
  spoke when it did not. A day's file may hold several runs, so a new `raise` row starts a clean
  slate and an earlier run's findings can never colour this one.
- **An app with no soak is a row, not a blank** — `unknown`, *"no soak yet — run bin/gates/soak.sh
  <app>"*, with the sampler's own last reading of it beside, so a reader sees the app is running
  even before a soak exists.

The three words the page says are **holds · grows · restarts**, and `unknown` is the honest
fourth. Every row names the number that broke, so a verdict is checkable, never a colour.

**The page draws it for a person.** `src/components/SoakHealth.tsx` (new) renders three panels on
the Runtime page: the ledger's state (when the last pass landed, whether the timer looks stopped,
the budgets behind a fold) with the budget and the source paths in prose; **Services** with a
count of grows/holds and a scrollable row per unit; **Apps — their last soak**; and the ward's
stops when there are any. `/api/runtime` is untouched; the heavy read is its own route,
`/api/soak`, memoised for 30 s so a 30-second poll never re-parses a growing file.

## How it was proved

**Planted worlds, 20 assertions** (`bun test server/health.test.ts`): a flat service holds; RSS
past 5 % grows and names the number; fds and watches and children each grow on their own; three
restarts in the window is a restart verdict; a counter that resets on a stop still sums to four;
a storm row is the verdict below the count; a stale ledger says its age and still reads; the
newest pass decides which services are shown; a soak judged `pass` holds; a judged `leak` grows in
its own words; an unjudged run is judged by §5 and says `unjudged`; a mid-run soak is `unknown`;
a `skip` names its reason; a not-responding dialog is never a pass; two runs in one file take the
last; a lone `storm-state.json` is not an app; an app with no soak carries the sampler's reading.

**The real window on this machine, through DevTools** (`YMIR_DEVTOOLS_PORT`): the gate ran from this
worktree on `:3897`, the SPA was built from it and served on `:3988`, and an Electron window
loaded it; Playwright over CDP (`:9421`) opened `#/runtime`. Measured against this machine's real
ledger:

```
Health — every service and app, measured · last pass 5 h 59 min ago · 15 passes
  the ledger has not moved for 5 h 59 min: the sampler writes every 5 min, so the timer is
  likely stopped on this machine. The trend below is the ledger's own last 30 min…
Services — 33 on this machine · 5 grow · 27 holds · 1 unjudged
  hlidskjalf-gate  89.1 MB +42.4 % · fds 37 (+18) · children 5 (+4)          grows
  issue-watch     574.8 MB +1670.9 % · fds +69 · watches +227               grows
Apps — their last soak — 1 soaked · 5 waiting
  sessrumnir      the soak judged it a pass / unjudged §5 …                 holds|grows
  bilskirnir      no soak yet · the sampler last saw it running at 124.4 MB  unknown
```

`tsc --noEmit` clean, `vite build` clean, **zero console errors** in the window. The verdicts
moved with the live writer while the proof ran (the `leak-soak` errand was soaking Sessrúmnir on
this machine at the same time), which is the point: the page reads what the writer lands.

## Not done, named

- **`bin/gates/soak.sh` is another errand's (`leak-soak`) work and is not merged.** This page
  reads its rows exactly as they land; it does not own, change or fake them. Until that branch
  merges, only the apps it has actually soaked have a soak row.
- **The sampler timer was not enabled by this errand.** It is a per-machine user timer, seated by
  the machine's own holder (RULES/41, RULES/55); the ledger here is the one the `leak-ledger`
  errand proved, and the view says plainly when it has stopped.
- **No second-machine proof from a release.** a second machine needs a release built from a branch
  that is not merged; nothing on a screen was changed there, and no window was driven on another
  machine by a worker.

## CHANGE LOG

- 2026-11-14 — the Health view (plan 286 P6): `/api/soak`, `server/health.ts`, the three Runtime
  panels, 20 planted-world assertions, and the real-window proof above.
