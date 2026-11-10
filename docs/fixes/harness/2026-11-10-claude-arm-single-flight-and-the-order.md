## harness · 2026-11-10 — the Claude arm: one client, only for the helm, and a wake that carries its order

### What
`bin/gates/checks/claude-stop-arm.sh` replaces the inline Stop command in `.claude/settings.json`:
(1) a session that does not hold the Gleipnir lock never arms; (2) an exclusive `flock` on
`<state>/.claude-arm.<session>.lock` keeps exactly one client per session; (3) an actionable line is printed with the
instruction Pi's extension gives (`saga-wake-drain.sh` first, `ack`, answer Rödd with `rodd-room.sh reply`) and exits 2.

### Why
Proven the same evening (plan 239): with Claude holding the lock, Rödd's wake roused the idle session — but seven arm
clients had piled up (Claude never de-duplicates async hooks), one still attached to the previous service generation,
and the banner was a bare `signal: wake queue` with no instruction.

### Verified
A second firing while the first holds the lock exits 0 within a second. The end-to-end wake was proven before the
wrapper (plan 239 §Proof); the wrapper's own end-to-end run is the next turn end after merge.
