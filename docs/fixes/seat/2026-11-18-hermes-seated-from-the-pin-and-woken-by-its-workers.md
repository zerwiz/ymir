## seat · unversioned · 2026-11-18 — Hermes is seated from the pin, corrected on every update, checked by value, and woken by its workers

### Why

Plan 317 measured on 2026-11-18 that Hermes ran Ymir's MCP door from a working tree, not from the pin. The seat never corrected a live entry, so a wrong path stayed wrong for ever. Its `--check` compared names, so it passed while the values were wrong. Its caller sent every failure to `/dev/null` and printed "not installed".

Two more faults sat beside those. The descriptor said Hermes had no hooks and no native MCP, which was false for both. A finished herdr worker reached the operator only as a cron note, never as a turn, and the stopgap watcher died with the agent's session.

### What changed

| Slice | Change |
|---|---|
| 1 | `bin/bridge/mcp-config-seat.py` renders the `ymir` door on the pin's link path (`~/ymir-runtime/bin/mcp/ymir-mcp.py`), read from `ymir_runtime.paths.runtime_pin_dir`. It also gains `--dry-run`, which prints the JSON diff and writes nothing. |
| 2–3 | The Hermes seat moved into Python: `src/ymir_runtime/hermes/seat.py`. `bin/seat/hermes-seat.sh` is now a one-line launcher. Ownership lives in a side ledger, `~/.hermes/.ymir-owned.json`. Owned entries are corrected, the operator's entries are left alone and reported `operator-owned`, and `--check` compares values. Writes go through `hermes config set`, so Hermes' own writer keeps its format. A dated backup is taken first. |
| 4 | `bin/seat/valknut-load.sh` prints the seat's own lines and names a failure with its exit code. Only a host without `hermes` reads as "not installed". |
| 5 | `.agents/harnesses/hermes.yaml` now says `hooks: shell` and `mcp: native`, and adds `measured_against: 0.22.6`. `bin/seat/harness-extensions-install.sh` gains a `hermes` row in both install and `--check`. |
| 6 | The seat adds `<pin>/.agents/skills` to Hermes' `skills.external_dirs`, so the shelf loads in every working directory. It removes trust entries that point at transient `.yggdrasil` worktrees. |
| 7 | `bin/seat/hermes-session-hook.sh` is a launcher for `session_hook.py`. The digest is injected on the first turn in any working directory (RULES/51). It is taken on the first turn if the start hook never stashed one. `YMIR_HERMES_DIGEST_SCOPE=house` keeps the old scope. |
| 8 | `ymir doctor hermes` (`src/ymir_runtime/hermes/doctor.py`) prints one row per surface with four states per door. It makes one real read-only call per owned door, checks that `ymir_where` names the pin's release, and exits 0 only when every surface answers. |
| 9 | `ymir wait-worker` (`wait_worker.py`) starts a transient systemd user unit, so the waiter is supervised rather than a child of the session. When a herdr worker is not working and has a handoff, the unit delivers a turn into the session that started the wait, through `hermes chat --resume <id> -q … -Q`. A paused session is never written into, and a busy one is waited for. The seat installs `~/.hermes/scripts/ymir-workers.py`, a `.py` file, for the cron's `--once --cron` note. |

One more fix was in the way of slice 8. `bin/engine/ymir.js` moved to `bin/engine/` but still resolved its root one level up, which pointed at `bin/`. Every door run from the tree therefore answered "missing from this install". The root is now two levels up, and the verbs `doctor hermes`, `hermes <verb>` and `wait-worker` run the Python core.

### Files

- `bin/bridge/mcp-config-seat.py`
- `bin/seat/hermes-seat.sh`, `bin/seat/hermes-session-hook.sh`
- `bin/seat/valknut-load.sh`, `bin/seat/harness-extensions-install.sh`
- `.agents/harnesses/hermes.yaml`
- `bin/engine/ymir.js`
- `src/ymir_runtime/hermes/` (`common`, `seat`, `doctor`, `mcp_probe`, `session_hook`, `wait_worker`, `cli`)
- `src/ymir_runtime/tests/test_hermes_{seat,wait_worker,session_hook,doctor}.py` (28 tests)

### Proof

The proof is in `docs/handoffs/w-ymir-seat.md`. Each slice's done-when command was run on heimdall, and its output is quoted there.

## CHANGE LOG

- 2026-11-18 — filed with the errand `w-ymir-seat` (plan 317 slices 1–9).
