# The gate serves the door it has documented since plan 199

**2026-11-09 · component: hlidskjalf · `apps/hlidskjalf/server/index.ts` · `apps/odrerir/src/components/NearBoard.tsx`**

The governed asset `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md` has listed four
near-loop carriers since 2026-11-06 — `/api/core-four`, `/api/pending`, `/api/context`,
`/api/plans`. The gate served three. The fourth was a document, not a route.

## What was wrong

`GET /api/context` answered `{"error":"no route /api/context"}` on this seat and on the
heart, while `bin/seat/context.sh --json` behind it answered correctly
(`134538 used · 13.5% of 1000000 · 865462 left · verdict: room to work`). The near board reads
that door for the window card's session line, so the line simply never appeared —
`git log -S "'/api/context'" -- apps/hlidskjalf/server/index.ts` is empty: it was never
written, by anyone, at any commit.

Two smaller untruths sat next to it on the same screen:

- the window card rendered `context.window` directly, so *unknown* and *zero* looked the same;
- the footer advertised jev's Hype · Facts · Signal, while `src/vendor/jev/policy.ts` is
  imported for its types only and no code computes a score — hence "Not ranked yet" on every
  card beneath a promise of scores.

## What it does now

- **`/api/context` is served**, as a carrier beside its neighbours: `execFileSync('bash',
  [bin/seat/context.sh, '--json'])`, `cwd: ROOT`, an explicit 30 s timeout, `memoAsync(15 s)`,
  and an `error` object on failure so the panel paints *did not answer* rather than a zero.
  `/api/core-four` also gained `cwd: ROOT` so a carrier never inherits a caller's directory.
- **The window card tells the truth in three states**: `≈ 1,000,000 tokens` when the catalog
  rounds, an exact figure when a registry knows it, and *window unknown* plus the door's own
  reason when neither does. It also names its source (`catalogue (rounded)` vs
  `models.json`).
- **The footer stops advertising unwired scores** and points at `bin/model/jev-doors.sh list`;
  the card keeps "Not ranked yet", which is what jev's policy says to do.

## Proved

A gate started from this worktree under the **unit's own environment** —
`env -i HOME=… PATH=…/.bun/bin:/usr/bin:/bin bun run server/index.ts` on port 3999 — answered:

```
/api/core-four → context{window:1000000, auto:500000, force:750000, known:true, approx:true, source:catalogue}
/api/context  → {turns:64, context_used:135730, window:1000000, percent:13.6, verdict:"room to work"}
```

Before the change the same route was `404 no route /api/context`, and `window` was `0`.
`apps/odrerir` typechecks clean (`tsc --noEmit`, exit 0).

## Guard

`bin/seat/tests/test_doors_fleet_path.sh` runs every near-loop door under the gate's trimmed
PATH, and the asset's §"the near-loop doors" now states that all four are served and that a
carrier must never depend on an interactive PATH.

## CHANGE LOG

- **2026-11-09** — `/api/context` served (15 s carrier, `cwd: ROOT`), core-four given `cwd`;
  the near board renders exact/approximate/unknown-with-a-reason and stops advertising jev
  scores it does not compute (plan 227).
