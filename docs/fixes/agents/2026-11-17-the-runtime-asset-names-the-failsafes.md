# The runtime asset now names the desk's failsafes

**2026-11-17 · component: agents · plan 001 §4 (the dead desk)**

## Why

A code change is not finished until the owning Galdr asset says the same thing. `bin/seat/*` and
`bin/voice/rodd-arm.sh` both answer to `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md`
(`bin/records/where.sh bin/seat/herdr-run.sh` names it, and `bin/voice/rodd-arm.sh` is governed by the
same runtime shelf).

## What changed

A new section at the foot of `brokk-distro-runtime.md` — **"The desk survives a death — the five
failsafes"** — records, in the asset's own voice:

- the death as measured (one child killed, the unit stopped with `oom-kill`, 27 panes back as shells);
- a table of the eight doors the plan now stands on, with the number each one is sized by;
- what the failsafes deliberately do **not** decide (the resurrection rule is the Allfather's, plan 001 §6);
- the residue, named rather than hidden: `hdr agent start` is unscoped, and the arm daemon writes its own
  lease without passing `hold`;
- the proofs, with the numbers they printed.

`bin/records/where.sh` also reports that `bin/voice/rodd-arm.sh` and `bin/notify/send.sh` have **no row** in
`.agents/assets/agents/subsystem-docs.md`. That gap is older than this change and is recorded here rather
than papered over: adding those rows is the next hand's honest work, and the runtime asset now carries the
substance in the meantime.

## CHANGE LOG

- 2026-11-17 — review-mend: added missing heading for #814
