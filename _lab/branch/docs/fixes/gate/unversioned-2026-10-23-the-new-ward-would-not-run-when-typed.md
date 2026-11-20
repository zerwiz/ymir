## gate · unversioned · 2026-10-23 — the new ward would not run when a hand typed it, and two catalogues each kept one row

### Why

Three faults, found while resolving the conflict on PR #400 and named here rather than
fixed silently.

**1 · `app-functional-guard.sh` refused to run with no argument.** Its header advertises
`[check] [--live]`, and the `case` maps the empty call to `set -- check` — but the argument
loop below it accepts only `--live`, so the ward met its own synthesised `check`, printed
`error: unknown option check` and exited **2**. `bin/gates/guards.sh` always passes `check`
explicitly, so the ward was green in the ward list and broken in the hand; a ward a person
cannot run is a ward that gets skipped. A clean skip is a pass (`RULES/25`), a refusal to
start is not. Fixed by mapping the empty call to **no arguments at all**, which is what
`check` means here. `defaults-guard.sh` carries the same `set -- check` line and is
**unaffected** — it has no strict argument loop, and running it naked is green (verified).

**2 · the rule index count was stale, because both branches appended one row to one tail.**
The merge conflict was not a disagreement: `main` appended the Desktop row *The halls and
their buttons* (PR #399) to `FEATURES.md` while this branch appended the Gate row *The apps
stay whole*; `main` appended rule **30** (*audio is ephemeral*, PR #401) to `RULES/README.md`
while this branch appended a dated section carrying rule **29**. Append-only law makes that
collision certain: two hands, one tail, one hunk. Resolved by **keeping every row of both
sides** — an erasure is not a resolution — which left the disk holding 30 numbered rules
against a declared `rules_index[29]`. The count is now `[30]`; no rule was renumbered and
no row was dropped.

### Files
- `bin/gates/guards/app-functional-guard.sh`
- `RULES/README.md`
- `FEATURES.md`
- `docs/fixes/gate/unversioned-2026-10-23-the-new-ward-would-not-run-when-typed.md`

### Verified
```
bin/gates/guards.sh                     13/13 PASS (rules-number-guard had been FAIL, count 29 vs 30)
bin/gates/guards/app-functional-guard.sh  (no argument) → runs: parses PASS, routes PASS (44 UI calls)
bin/gates/checks/readme-claims.sh       every claim resolves — 0 missing
RULES/README.md                         rows read 28 · 30 · 29 — numeric order of arrival, nothing lost
```
The out-of-order `28 · 30 · 29` is stated rather than tidied: renumbering is an erasure by
another name. Order is restored only by a new appended section, never by a rewrite.
