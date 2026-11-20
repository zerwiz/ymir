# REPORT — arm-closes-seats

**STOPPED** at Hœnir's word (arm holder): committed locally, **not pushed**, no PR opened.
**Local branch:** `eindri/arm-closes-seats-mends` · **tip:** `418fc1be` (merge of the rework onto
current `origin/main` @ `5ac55dd1`).

**PR:** https://github.com/zerwiz/ymir/pull/639 — SQUASH-MERGED 2026-11-10T22:33Z as `965c478b`
from tip `832c8305`, i.e. BEFORE the rework. The ten mends live only on the local branch above.
**Branch:** `eindri/arm-closes-seats` (rebased on `origin/main`, 3 commits, no merge, `main` untouched)
**Tip:** `c2b3b22f`
**Ward:** `bin/seat/tests/test_seat_reap.sh` — 59 cases, all green, stubbed `herdr` + throwaway `HOME`

## Forseti's rework — all six mended, plus the renumber

| # | finding | mend |
|---|---|---|
| 1 | the ward's stubbed herdr failed the house mocks scan; the PR body's "mocks PASS" was false | the fixture is **declared** in `mocks-scan.sh` with a reason, and `mocks-scan.test.sh` proves it is excused AND that a stub beside it is still caught. `compliance-check.sh`'s mocks row now **delegates** to that one scan instead of carrying a second copy — which is exactly why the two disagreed. PR body corrected. |
| 2 | `FEATURES.md` stale | re-woven: `current (205 entries)` |
| 3 | bin indexes behind | regenerated: `current — 35 index file(s), 910 bin doors` |
| 4 | `fdc7f86e` unpushed | pushed; the branch is now 3 commits past `origin/main` |
| 5 | a recordless workspace was closed, killing a booting seat | the spawner stamps `state/.<id>.launched`; the sweep keeps a seat inside `YMIR_SEAT_SETTLE` as **SETTLING**, closes it after, and keeps an unmeasurable one — the law of `tests/test_eindri_liveness_grace.sh`. 3 new ward cases. |
| 6 | comment said 120 s, code ships 60 | corrected |
| + | migration id `0018` already taken on main | renumbered to **`0019-a-worktree-is-not-a-root.sh`** (backup suffix `.pre-0019` too) |

## Per-file

**New doors**
- `bin/seat/seat-reap.sh` — the one closer: `<id>`, `--sweep`, `--list`, `--shell <worktree>`, `--install`, `--check`, `--verify`.
- `bin/seat/seat-wake.sh` — writes the seat's word into the ARM's queue (`state/.wake-queue`), once per (errand, kind).
- `bin/seat/seat-adopt.sh` — corrects a `seat=no` record whose pane now holds an agent, arms the watch, writes the `adopted` wake. `--all` / `--list`.
- `bin/seat/tests/test_seat_reap.sh` — the ward.

**Changed**
- `bin/agents/einherjar-spawn.sh` — records `workspace=`; sparse-checkout instead of `rm -rf` + `--assume-unchanged`; wake on an unproven seat; no second settle default.
- `bin/agents/eindri-dispatch.sh` — closes the seat on `close` and on a terminal review verdict (`return` keeps it).
- `bin/agents/eindri-arm.sh` — closes on the close hook and on retirement; a tidy seat is never a handoff ack.
- `bin/agents/eindri-start.sh` — resolves the ROLE's model via `bin/model/agent-model.sh` and prints `model[1]{agent,model,decided_by}`, naming a machine overlay that pinned a local model.
- `bin/agents/eir-doctor.sh` — new `seats` surface (fix mode runs the migration + `--install`).
- `bin/agents/groa-update.sh` — re-seats the sweep after every update; `--check` reports `PENDING` and mends nothing.
- `bin/engine/ymir-install.sh` — `seats` step (apply seats per harness; `--check` NAMES the faults).
- `bin/forge/housekeeping.sh` — `keep:in-use` now means an AGENT stands there; bare shell no longer holds a tree; shell closed before reclaim.
- `bin/pi/syn-watch-arm.sh` — sweeps as the helm is taken.
- `bin/time/saga-session-start.sh` — `SEATS` section: sweep + adoption, one TOON row of what closed.
- `bin/seat/valknut-load.sh` — never records a linked worktree as a root; prunes any recorded.
- `bin/seat/seat-prove.sh` — 60 s one default (`YMIR_SEAT_SETTLE`); a model-lock queue counts as alive.
- `src/ymir_runtime/seat.py` — passes `--settle` only when set; calls the shared wake door on an unproven seat.
- `.agents/migrations/0018-a-worktree-is-not-a-root.sh` — prunes linked-worktree roots (backup `.pre-0018`) and heals affected worktrees to the sparse-checkout exclusion.
- Assets: `brokk-distro-runtime.md`, `installation.md`, `harness-integration/README.md`; fix note `docs/fixes/agents/2026-11-10-the-arm-closes-finished-seats.md`; feature pages + catalogue row + woven `FEATURES.md`.

## Verified

- Ward: **59/59**. Sweep closes a closed and a recordless errand, never a live agent, a fresh record or the main hall; `--list` closes nothing; second sweep is a no-op; a bare shell closes and a live agent's pane is refused; housekeeping says `keep:unpushed` / `keep:dirty` / `keep:in-use` / `reclaimable:merged` correctly; the wake is exactly once; adoption flips `seat=no` → `seat=yes`, status → `working: adopted`, one `SEAT ADOPTED` wake; migration 0018 prunes with a backup, is idempotent, and turns 45 reported deletions into a clean `git status`.
- `ymir-install.sh --check` (throwaway HOME seeded with a `.yggdrasil/` root) → `"seats","WARN","5 fault(s) — … a real install/update heals it"`.
- `groa-update.sh --check` (same HOME) → `seat-reap: PENDING …`, mended nothing.
- `seat-reap.sh --verify` on this worktree: 5 faults before the mend, clean after; `git status` now shows only this errand's files.
- `src/ymir_runtime` `test_seat` 21/21. `test_dispatch`'s 2 `ModelUnavailable` errors reproduce on `main` — pre-existing.
- `.agents/tests/mocks-scan.test.sh`: all probes ok, including *"the shipped tree passes its own scan"*.
- `weave-features.sh --check` → `current (205 entries)`; `gates/inventory.sh --check` → `current — 35 index file(s), 910 bin doors`.
- Compliance: every row PASS except `config` (hardcoded paths in three `bin/gates/tests/*.sh`) — red on `origin/main`, untouched here. Eight pre-push wards are also red on `origin/main`; the guard says so and clears the push.

## Open questions (for the Allfather, not blocking)

1. **The four other broken worktrees on this seat** belong to errands that were LIVE while I worked; running migration 0018 against them could race their git operations. I left them. The next `ymir-migrate.sh apply` heals them — say the word if you want me to run it now anyway.
2. **`bin/gates/tests/{test_broken,test_finding_tally,test_pr_identity}.sh`** carry hardcoded `/home/zerwizserver` paths and keep the `config` gate red on `main`. Not mine to change in this errand; a one-line fix each.
3. **A `return` review verdict keeps the seat** (the work went back to the worker). If the house would rather close it and let the dispatcher raise a fresh one, that is a one-line change and a different law.

## Stopped — 2026-11-11, at the arm holder's word

Told to stop and not push. What stands:

- **Local branch** `eindri/arm-closes-seats-mends`, tip `418fc1be`, a merge of the ten mends
  onto current `origin/main` (`5ac55dd1`), so it lands beside the Claude-harness work (#644)
  that touched `bin/agents/eir-doctor.sh` and `bin/engine/ymir-install.sh`.
- **Conflict resolutions worth knowing:** main's eir-doctor had lost the `seats` surface
  (its `SURFACES` carried `claudehooks` but not `seats`); both now stand. Main's
  `ymir-install.sh` gained a `harness-extensions` check in the same `if` block — kept,
  with my `seats` verify block closed properly above it.
- **Second review's four, all mended:** the engine road (`src/ymir_runtime/worktree.py`)
  now uses the sparse-checkout exclusion instead of `rmtree` + `--assume-unchanged`;
  `test_worktree.py` asserts `git status --porcelain` is EMPTY and is proved to fail
  against the old road; the renumber to `0019` lands; the fix note appends a dated
  correction instead of editing landed lines (Rule 06).
- **Wards:** seat reap 59/59 · test_worktree 6/6 · test_seat 21/21 · mocks-scan probes.

**Inherited red, named not hidden:**
1. the `mocks` row now flags `bin/bridge/mcp-config-seat.py:317` — a `todo =` variable
   that landed on main with #644 — because the delegated scan is stricter than the copy it
   replaced. Either that variable is renamed, or the scan earns an exclusion with a reason;
   I did not invent one.
2. `config` flags `bin/gates/tests/test_broken.sh`, `test_finding_tally.sh`,
   `test_pr_identity.sh` (hardcoded paths) — on `main`, untouched here.
