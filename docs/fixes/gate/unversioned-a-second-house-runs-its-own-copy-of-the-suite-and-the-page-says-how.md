## gate · unversioned · 2026-11-15 — a second house runs its own copy of the suite, and the page says how

### Why
`docs/features/gimle-the-hall.md` documents the first house only. A second company running its own copy of the
collaboration suite is now a real, staged thing, and the six ways it goes wrong are all silent: a copied gate
secret that lets two installations forge each other's sessions, a copied credential dump, the first house's
access record travelling with the files, a literal `{{ secret }}` string accepted as a session secret, a PEM
folded onto one line by YAML quoting, and a staged unit that shadows a running one. None of them errors. Each is
answered on the page by a command that does.

### Files
- `docs/features/a-second-house-suite.md` (new)
- `docs/features/_catalogue/entries/00-1003-a-second-house-suite.md` (new catalogue row)
- `docs/features/gimle-the-hall.md` (a pointer to the new page)
- `docs/fixes/gate/unversioned-a-second-house-runs-its-own-copy-of-the-suite-and-the-page-says-how.md`

### What
A how-to page for the operator: the service account and group, the copy with a named exclusion list, the secrets
generated on the machine that will use them, the gate's four-to-any members, the units with `Conflicts=`, the
house's own names, one token per member, and a proof table whose every row is a command. It names no host, no
address and no company: the page is public.

### Verified
The page is written from a staging that was run and proved on a rented host on 2026-11-15: `authelia
validate-config` clean with the secret store mounted and the template filter on; `systemd-analyze verify` exit
0 on three staged units that measured `disabled`/`inactive`; the first installation's units measured `active`
with their original start times; a content `grep` of the staged tree for the first house's domain, brand and
collaborators returning no file; and the same comparison by SHA-256 showing every new gate secret `not equal`
to the first house's. The two gate traps were found by testing the literal-template case on purpose rather than
by reading the manual: without `--config.experimental.filters template` the bogus-function and missing-file
cases both pass validation.

## CHANGE LOG

- 2026-11-15 — written with the staging it documents.
