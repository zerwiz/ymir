# seat · unversioned · 2026-11-14 — a fixture names nobody

A repair to the work of the same day, found in review: the first version of
`bin/seat/tests/test_seat_find.sh` carried a real collaborator's first name in its planted pane text,
in the query the test sent, and — worse — paired it with pronouns. The same name had reached this
door's own report example in `bin/seat/seat-find.sh`.

That is personal data in a public tree, which RULES/04 refuses whatever the file is for. A test needs
a token that is unique, not a person.

## What changed

- The fixtures plant **`quillfern`**, an invented word that names nobody, in the pane text, in the bare
  shell that must never be searched, and in the query.
- `bin/seat/seat-find.sh`'s report example is shaped placeholders now.
- `docs/fixes/seat/2026-11-14-the-find-door-reads-the-work.md` records the measurement that was
  re-run with a neutral word (`whole-tree` named the one worker whose screen carries it and skipped the
  caller's own pane), and says why a fixture written from a search for someone's work must not carry
  the person.

## Files

- `bin/seat/tests/test_seat_find.sh`
- `bin/seat/seat-find.sh`
- `docs/fixes/seat/2026-11-14-the-find-door-reads-the-work.md`

## Verified

`bash bin/seat/tests/test_seat_find.sh` → **13 ok, 0 failed** — the same thirteen checks as before the
repair, because the token is a token either way. `bash bin/gates/guards/people-guard.sh` → clean, and a
grep of the branch's whole diff for the name finds nothing.
