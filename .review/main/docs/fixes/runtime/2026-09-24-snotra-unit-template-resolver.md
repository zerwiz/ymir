## runtime · 2026-09-24 — the ear's unit template was unreachable

### Why
`autoboot-lib.sh` declared **snotra** as a heart-owed program, and
`tools/mill/systemd/snotra.service` shipped — but `fleet-ensure.sh`'s
`PROGRAM_UNIT_SRC()` case never listed it, so the resolver fell through to
`*) return 1`. The heart's ensure then reported:

```
fleet: whynot owes (heart forge): … skuld snotra embed nornir
fleet: snotra — no unit template (tools/mill/systemd/snotra.service missing)
fleet: FAIL — could not raise snotra.service
```

The template was present the whole time (322 bytes). This slipped in while resolving the
PR #179 merge: the ear's *declaration* was added to the program table, and its tool, its
URL and its MCP wiring to `fleet-ensure.sh`, but not its **unit** — so the one road that
materializes the unit could not see it.

**Worth noting: the boot law caught it.** It did not pass silently, did not warn, and named
the exact missing artifact — which is precisely what the 2026-09-24 autoboot work exists to
do. A gap this shape used to be invisible.

### What
- `bin/fleet-ensure.sh` — `PROGRAM_UNIT_SRC()` now resolves `snotra` with the rest of the
  mill/offices.

### Verified
- The heart's `fleet-ensure.sh ensure` after the fix materializes the unit, enables it into
  `ymir.target.wants/`, and raises it; `:8321` answers.

### Files
- `bin/fleet-ensure.sh`
