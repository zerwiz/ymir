## agents · 2026-11-12 — Eir reads the mail desk where it stands and says what is red

### Why
Eir's `mail` row probed `:8490`, but the mail desk listens on `:8494` (the install, the unit, the Nornir job and the autoboot table all say so; `:8490` is the Gimle share port). The row read "no answer" on a seat whose desk was healthy. The default now matches the desk.

Three rows also read wrongly. `seats` printed `the seat wire` with no newline and then the TOON header of `seat-reap --list`, so the row looked malformed. It now says which harnesses the seat wire is not seated on, or where it is. `claudehooks` printed one fixed sentence whatever the state; it now names the `claude-*` rows the installer's own check calls stale, and points at the pinned runtime as the usual cause. `hoard` counted an empty `.agents/state` or `bin/state` inside the repo as state in the tree; an empty leftover is harmless, and `eir-doctor fix` now removes it.

The installation and Nornir assets named `:8490`; they now say `:8494`.

### Files
- `bin/agents/eir-doctor.sh`
- `bin/agents/tests/test_eir_mends.sh`
- `.agents/skills/galdr-ymirsystem/assets/installation.md`
- `.agents/skills/galdr-ymirsystem/assets/nornir-jobs.md`
