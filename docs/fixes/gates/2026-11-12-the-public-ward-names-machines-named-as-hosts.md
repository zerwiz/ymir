## gates · unversioned · 2026-11-12 — the public ward counts fleet machines named as hosts, and says what it judged

### Why

Plan 278 asked why the public ward reported nothing while fleet machine names sat in public files. It was
proved on 2026-11-12:

- The ward CI runs (`public-guard.py`) had no class for a machine name at all. Topology was judged by shape
  only: a private address, or a tailnet name. A bare machine name could never match.
- Its list of the operator's own words held two entries, and nothing else from the home was read.
- The older shell ward (`public-guard.sh --tree`) disagrees with it, and its `--all` mode prints nothing on a
  pass, so a run looked silent.
- A plain word count over-states the problem. One fleet machine shares its name with a figure of the lore, so
  most files that "name" it name the figure. Another registry row is a generic loopback name.

### What changed

- **A fifth class, `machine`.** The names are read at run time from the home's fleet registry
  (`$YMIR_HOME/hodd/data/fleet.json`, `hosts`, or `YMIR_FLEET_REGISTRY`). A name is judged only where it is
  used as a host: after `@`, `ssh`, `host=`/`host:` or a URL scheme, or before a port, an mDNS suffix or a tailnet suffix.
  Generic names (`localhost`, `unknown` and kin) and the repository's public owner are not judged. The ward
  never prints a name; each finding says the name is masked on purpose.
- **Advisory until the operator says otherwise.** Machine findings are counted and listed, and the ward still
  passes. `--strict-names` (or `YMIR_PUBLIC_GUARD_STRICT=1`) makes them binding.
- **The scope, always.** Every run prints `public_guard_scope`: files judged, files exempt, words loaded,
  machine names loaded, and whether the class is binding. Counts only.
- **The canary.** `bin/gates/checks/public-data-ward.test.sh` plants a fake registry: a machine named as a host
  is counted, advisory by default and refused under `--strict-names`; the name is masked; the same word in
  prose and a generic name pass; the scope line is printed; and the ward carries none of the real fleet's
  machine names.
- **The live tree is swept.** Every live file the class found now uses a role or a placeholder: the contract
  line on the A2A backbone, two Galdr assets, a feature page, three tests, and the Hlidskjalf server, which
  carried two machine names as its default server seats. That last one is its own note
  (`docs/fixes/hlidskjalf/2026-11-12-the-cron-board-reads-its-seats-from-the-fleet.md`).

### What was not changed, on purpose

- **The operator's own domain stays on the allow-lists.** Both wards name it as the public owner identity, the
  licence holder, by a decision recorded on 2026-11-03. Plan 278 calls it private; the earlier decision stands
  until the Allfather rules otherwise.
- **No history was rewritten.** A scrub of published history is the Allfather's to seal.

### A correction for older notes (RULES/06)

These append-only fix notes name a fleet machine as a host. They stay as written. Read each such name as the
role it served: the heart, a server seat, or the operator's dev seat.

- `docs/fixes/agents/2026-11-05-the-sweep-turns-to-the-pane.md`
- `docs/fixes/install/2026-09-23-the-pretest-checks-every-seat.md`
- `docs/fixes/install/2026-09-23-the-pretest-on-its-own-seat.md`
- `docs/fixes/install/unversioned-2026-10-12-a-seat-that-cannot-speak-now-says-so.md`
- `docs/fixes/model/2026-11-09-the-jev-doors-answer-and-the-register-lied.md`
- `docs/fixes/odrerir/2026-09-27-the-hall-reads-the-living-door.md`
- `docs/fixes/odrerir/2026-11-09-the-hall-ranks-with-a-measured-judge.md`
- `docs/fixes/runtime/0.1.57-the-contract-said-the-a2a-backbone-was-unbuilt-it-was-an.md`
- `docs/fixes/runtime/2026-09-23-mcp-by-role.md`
- `docs/fixes/seat/2026-11-05-the-seat-wire.md`

### Proof

- `bin/gates/checks/public-data-ward.test.sh`: every case behaves, the six new ones included.
- `public-guard.py --tree` on a seat with a fleet registry: 16 advisory lines in 11 files, all in the
  append-only notes above (it was 26 lines in 18 files before the sweep). Exit 0.
- `public-guard.py --tree` with no home (as in CI): the machine class loads no names and the scope line says so.
- The swept tests pass: `test_lease_fields.sh` 6, `test_rodd_arm.sh` 61, `ymir_runtime.tests.test_watch` 70.

### Files

- `bin/gates/guards/public-guard.py`
- `bin/gates/checks/public-data-ward.test.sh`
- `AGENTS.md`
- `.agents/skills/galdr-ymirsystem/assets/odrerir-hall.md`
- `.agents/skills/galdr-ymirsystem/assets/thing-assembly-hall.md`
- `docs/features/the-well-on-every-role.md`
- `docs/features/the-wards-the-delivery-gate.md`
- `bin/pi/tests/test_lease_fields.sh`
- `bin/voice/tests/test_rodd_arm.sh`
- `src/ymir_runtime/tests/test_watch.py`

## CHANGE LOG

- **2026-11-12** — Opened.
