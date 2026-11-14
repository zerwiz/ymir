## gate · unversioned · 2026-11-14 — the gate list is a directory so two branches adding two gates never conflict

### Why
Measured by the heart on 2026-11-14: every open pull request conflicted with every other in ONE file, bin/gates/ci-verify.sh, because each branch appended its gate line there. Fourteen sound PRs could not merge on that alone.

### Files
- `bin/gates/ci-verify.sh`
- `bin/gates/checks.d/`
- `bin/gates/tests/test_gate_directory.sh`
- `bin/gates/inventory.sh`
- `bin/gates/capabilities.sh`
- `bin/gates/checks/guards-scope.test.sh`
- `bin/gates/guards/fixes-guard.sh`
- `.pi/extensions/rules.ts`
### What

`bin/gates/ci-verify.sh` no longer holds any gate. It is a driver: it resolves the repo, opens the
verdict file, defines `gate` (the row, the tail on failure, the verdict entry), seats the merge
driver, then reads `bin/gates/checks.d/*.sh` in C order and sources each file. Every gate moved,
unchanged, into its own file — command, description and the comment that explains it:

```
bin/gates/checks.d/0000-lib.sh             the helpers (nodelete_base) — not a gate
bin/gates/checks.d/0010-ward.sh            … one file per gate …
bin/gates/checks.d/0390-pr-pretest.sh
```

The numbers are zero-padded so C order is numeric order: a gate added at `0325` runs between `0320`
and `0330` without anyone editing the driver. **To add a gate, add a file.**

Four things make the split safe rather than merely tidy:

- **An empty list refuses.** A driver that runs no gate would print a bare header and exit 0 — the
  false green this house has paid for before. A missing or empty `checks.d/` exits 2 and says so.
- **A gate file that cannot load is a FAIL row**, never a skip: the driver tests the source and
  records the failure against the file's own name.
- **A gate file is not a door.** `bin/gates/inventory.sh` and `bin/gates/capabilities.sh` exclude
  `bin/gates/checks.d/` from the registers, so adding a gate rewrites no register and two branches
  cannot meet again in a generated file.
- **Every reader of the gate list follows it.** `.pi/extensions/rules.ts` (`ymir_gates`) reads the
  fragments and then the driver; `bin/gates/checks/guards-scope.test.sh` finds the ward line
  wherever it is kept; `bin/gates/guards/fixes-guard.sh` maps `bin/gates/checks.d/*` to the `gate`
  component so a fix note can cover it.

### Verified

- **Nothing was dropped or weakened.** The `gate` invocations were extracted from
  `origin/main:bin/gates/ci-verify.sh` and from the new files and compared as
  `(name, description, command)` triples: **42 = 42, same order, zero triples differing**.
- **The run is the same run.** `bin/gates/ci-verify.sh` was run on `origin/main` before the change
  and on this branch after it, and the rows were compared gate by gate. The line-by-line comparison
  lives in the errand report under `$YMIR_HOME/state/eindri-reports/`. The one row that differs is
  `identity`, whose judged range moves when a new commit exists (`HEAD^1..HEAD^2` on main's own merge
  commit, versus `origin/main..HEAD` on a branch) — the gate itself is untouched, and it is green for
  this branch's own commits.
- `bin/gates/tests/test_gate_directory.sh` — 18 checks, all green: two branches each adding a gate
  merge with no conflict and both run; the rows follow file order; a failing gate file fails the run
  with its own output and its verdict entry; an unloadable file is a FAIL; an empty or missing
  directory exits non-zero; the driver carries no gate line; the real list still holds its gates.
- `bin/gates/registers.sh check` — both registers `current` after regeneration.

## CHANGE LOG

- 2026-11-14 — the note that ships with the change: the gate list is a directory, and every reader of
  it follows the directory.
