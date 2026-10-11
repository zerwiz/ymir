## gate · unversioned · 2026-10-11 — rule 17: no dead code, and the ward that finds it

> Renumbered from rule 16 to **rule 17** when merged: rule 16 is the confidential
> session (PR #315). The ward list carries both `confidential-guard` and
> `dead-code-guard`.

### Why
Code that exists and is never reached is a claim that a feature exists. Added RULES/16-no-dead-code.md, bin/gates/guards/dead-code-guard.sh, and dead-code.allow; registered the ward in bin/gates/guards.sh so it runs wherever the tree wards run. The guard finds two shapes: a source file with no importer (apps/ packages/ tools/ src/, checked against an index of every import specifier in the tree) and a shell function defined and never called (bin/, scripts/). First run, measured 2026-10-10: 307 files scanned, 5 findings, each baselined in dead-code.allow against TODO.md section G1. Three bugs were found and fixed in the guard itself before it was useful: grep -q piped into grep -v is self-cancelling and reported 311 of 329 files as dead; sed with a greedy .* against the last quote stripped every import specifier and left the index EMPTY, so every file looked unreached; and an inline comment inside a shell pipeline was a syntax error. It also excludes templates, fixtures, build output (out/ dist/ build/), config files (*.config.*), service workers, Electron preloads, public/ and resources/ - each was a false positive on this real tree, and a guard that is wrong on its own input gets switched off, which protects nothing. The allowlist accepts exactly two kinds of line, neither a deferral: a named external consumer, or a work item (todo:) that DELETES the line when it closes. A reason of later/maybe/future/for now/temporary/TODO is rejected. What it cannot see is stated in the rule: an export used only inside its own file, an unreachable branch, a constant nothing reads, a file reached through a runtime-built string.

### Files
- `RULES/16-no-dead-code.md`
- `bin/gates/guards/dead-code-guard.sh`
- `bin/gates/guards.sh`
- `dead-code.allow`
- `TODO.md`