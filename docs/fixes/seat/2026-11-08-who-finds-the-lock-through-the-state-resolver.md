# who.sh finds the lock through the state resolver

**2026-11-08 · component: seat**

`bin/seat/who.sh` built the lock path from `HOME` plus a literal state directory. The seat already has a
resolver — `YMIR_STATE_DIR`, then `XDG_STATE_HOME`, then `HOME` — so reading it that way is both the
law (RULES/07 · nothing restated) and the true behaviour on a seat that sets `YMIR_STATE_DIR`.

Verified: `bin/seat/who.sh --me` still answers
`"w3:p1Z","w3:p1Z · ymir · errand:voice-593303 · lock-holder,me",...` after the change.

## CHANGE LOG

- **2026-11-08** — Opened with the fix.
