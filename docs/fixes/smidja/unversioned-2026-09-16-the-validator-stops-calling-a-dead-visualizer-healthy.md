## smidja · unversioned · 2026-09-16 — the validator stops calling a dead visualizer healthy

### Why
`bin/ymir-validate.sh` reported `visualizer PASS "UI built and served on :8437"`
by looking at `./dist` alone. When the API had crashed on a bad `CMD_DB` and
nothing was listening on `:8437`, the validator still said PASS — the false-pass
class this night kept surfacing, in the very tool meant to catch it.

- **The check now probes the port as well as the build.** `dist` missing → FAIL;
  built but nothing on `:8437` → FAIL with the fix (`run scripts/start.sh`);
  built and listening → PASS. A PASS now means the thing is actually up.
- **The smidja-db check resolves the same DB pair** `scripts/start.sh` and
  `bin/smidja-bootstrap.sh` do (an existing `$YMIR_HOME/smidja/smidja.db` first,
  then an in-repo copy, `SMIDJA_DB` override) — previously it named the home path
  only, so an in-repo DB read as missing.
- `galdr-reread`: `assets/installation.md` — a `visualizer` PASS means built *and*
  listening.

### Files
- *(carried from the frozen CHANGELOG.md)*
