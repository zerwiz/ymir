# hlidskjalf · 2026-11-14 — the digest's example names no machine

**Component:** hlidskjalf · **Branch:** `eindri/leak-health-view` (carries `eindri/hall-follow`'s name fix,
`77173807`)
**Files:** `apps/hlidskjalf/server/digest.ts` (one comment line),
`docs/fixes/hlidskjalf/2026-11-14-every-realm-skrymir-the-home-and-a-runtime-page-for-a-person.md` (one
example line)

## Why

`readHelm()` in `server/digest.ts` carries a comment that showed a concrete host and seat as its example
(a machine's own name · a role), and the Runtime fix note's proof transcript showed
`view.helm {seat <a seat>, machine <a host>, …}`.
A shipped note and a shipped comment must name no machine (RULES/25): the file is public,
and the example is exactly what a reader copies.

## What changed

Two lines, no behaviour: the comment's example is `host-a · dev`, and the transcript's is
`{seat <a seat>, machine host-a, role dev, pin <a sha>}`. The parse rules are untouched — the value comes
from the digest at run time, never from the example.

## How it was proved

`npx tsc --noEmit` clean; the file's only change is comment text, and the page renders the same values from
the same digest on this machine.

## CHANGE LOG

- 2026-11-14 — the two examples name no machine; the parser is unchanged.
