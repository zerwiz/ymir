## gate · 2026-11-14 — this gate becomes a file, after #767 made the list a directory

#767 landed while this branch was open: `bin/gates/ci-verify.sh` no longer holds gate lines, it reads
`bin/gates/checks.d/<NNNN>-<name>.sh` in C order. So the merge conflicted on exactly the line this branch had added.

Resolved by the rule the Allfather gave: main's `ci-verify.sh` taken **whole** (it now carries no gate lines at all),
and this branch's gate moved out into `bin/gates/checks.d/0400-guards-inherited.sh` — same header comment, same
`gate <name> "<description>" \` + command pair, numbered at 0400 because main's highest is 0390.

`bash -n` clean on both; `bin/gates/tests/test_guards_inherited.sh` still answers `5 ok, 0 failed`.
