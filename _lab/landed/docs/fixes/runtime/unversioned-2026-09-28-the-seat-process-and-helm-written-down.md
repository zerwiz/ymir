## runtime · unversioned · 2026-09-28 — the seat, the process, and the helm, written down

### Why

The day's supervision churn was three beings confused for one: the session lock
flapped (a process claim read as a session right), the `.seated` marker went
stale (a dead pid in the seat), and a resumption gained a new pid that had to
re-seat. The Allfather asked the model plainly ("is PID linked to session ID?"),
and the answer is now law: **session is a durable log identity (one session may
wear many pids); pid is a moment (numbers are reused); the helm is a per-pid
claim (one pid, the seated primary); the watch is lease-based and
session-independent.**

### The fix

- `docs/lore.md` gains **§XXXIII — The Seat, the Process, and the Helm**: the
  scroll (session), the body (pid), the seat (helm), and the watch beyond all
  three — in the chronicle's voice.
- `brokk-distro-runtime.md` gains the seat-model doctrine table (four beings,
  their implications: liveness checks, re-seat on restart, stale-marker wards,
  the inbox road for ended panes).
- Nothing rewritten; appends only. The `eindri-send` inbox fallback and the
  stale-marker ward remain the named follow-ups this doctrine makes precise.

galdr-reread: the naming map (Sýn), the runtime spec.

### Files

- `docs/lore.md`
- `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md`