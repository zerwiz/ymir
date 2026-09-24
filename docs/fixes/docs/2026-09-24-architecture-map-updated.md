# docs · 2026-09-24 — Architecture.md carries the day's guarantees

## Why
The architecture map had not yet learned what the day forged: the one
Electron runtime resolver, the routing class invariant, the graphics policy,
the Cron gate's two faces (local + whynot · zerwizserver over the ssh ring),
the folding Files tree, Nornir's both-orders role gate, session-started loops
and the boot gap, and Glitnir's honest GitHub read. A map that lags the code
teaches the wrong machine.

## What
- `docs/Architecture.md` §3.9 gains the UI/runtime truths: the resolver +
  absence-is-never-success, `bin/desktop-verify.sh` + the class invariant,
  `bin/graphics-lib.sh` (hybrid → software render, `YMIR_DESKTOP_DISABLE_GPU`
  overrides), the Cron gate's `/api/cron` + `/api/cron/seats` (ssh ring,
  machine-local), and the folding Files tree.
- §3.10 gains Nornir/Glitnir truths: the role gate parses before OR after the
  time (a loop embeds its parser at spawn), loops start BY a session (the
  supervised `nornir.service` decision pending, plan 54), and Glitnir reads
  real GitHub — `reviewDecision` → `approved`/`changes`, `{cards, ghError}`,
  explicit `--repo`, real-PR counting, 30s refresh.

## Files
- `docs/Architecture.md`