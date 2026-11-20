## gate · unversioned · 2026-10-23 — main was red on three rows, and the index needed two passes

### Why

While resolving PR #400 the local `bin/gates/ci-verify.sh` still refused after the conflict was
gone. `main`'s own push run of 2026-10-23 01:14 (`39882883495`) was red on the same rows, so
these were inherited, not introduced — named here because a gate that fails on the branch and on
main is a gate nobody can trust to mean anything.

**1 · the capability register was stale (509 doors against 547).** `bin/gates/capabilities.sh`
regenerates `.agents/assets/agents/capabilities.md` from the tree; main had added doors
(`asks.sh`, `backup.sh`, the audio-retention set) without running it. Regenerated: **564 door
rows**, `--check` current.

**2 · the mocks gate bit a word, not a stub.** Two files, one fault. `bin/assistant/smoke.sh`
reported a research failure with the message *"fell back to the stub — Exa unreachable"*;
`bin/assistant/research.py`'s own docstring said the search is not invented *"from a stub"*.
`compliance-check.sh` greps the shipped `bin/` for `mock|stub|placeholder|todo`, and it is right
to: a stub in the runtime is a lie about a feature. But nothing here is a stub — `research.py`'s
fallback is Wikipedia's **public API**, a real door. Both sentences were false *and* cost the
row. Reworded (*"the open encyclopaedia"*, *"a stand-in"*): the fix is the truth, not an
allowlist entry.

**3 · the generated index is only stable after a SECOND pass, and no note said so.**
`bin/gates/inventory.sh` derives each door's `callers` count by scanning the tree — **including
`bin/README.md` itself**, which names every door. When the regenerated index adds a row for a
door that was not listed before, that door's count is computed from the *old* file (`0`) and the
new file immediately contradicts it. One generation therefore cannot converge when the set of
rows changes; two can. Measured, after the first write:

```
run 1  diff lines: 120   (every new row's caller count +1)
run 2  diff lines: 0
run 3  diff lines: 0
inventory --check: bin/README.md is current (553 files)
```

The generator is not wrong to count the index — the index is a caller, it names what it lists.
What was missing is the second pass. **Mend:** run `bin/gates/inventory.sh` until `--check` is
clean, not once. A generated index that is "written" but not "current" is the stale-readme fault
this PR is about, one layer down.

### Files
- `.agents/assets/agents/capabilities.md`
- `bin/assistant/smoke.sh`, `bin/assistant/research.py`
- `bin/README.md`, `.agents/backend/README.md`
- `docs/fixes/gate/unversioned-2026-10-23-main-was-red-on-three-rows.md`

### Verified
```
bin/gates/inventory.sh --check        bin/README.md current (553 files) · backend current (175)
bin/gates/capabilities.sh --check     current (564 door rows)
bin/gates/ci-verify.sh                compliance PASS · inventory PASS · capability PASS · pr-pretest PASS
```
One row was **not** mended here, on purpose: `queue` fails on the SEAT because
`$YMIR_HOME/…/plans/queue.md` is behind the home's own plan ledger. That is a home write, not a
tree write, and CI (which has no home) reads it as PASS. Regenerating the home's queue belongs
to the home, not to this branch.
