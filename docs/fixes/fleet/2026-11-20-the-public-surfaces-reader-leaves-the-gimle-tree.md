# The public-surfaces reader leaves the Gimlé tree

**Component:** fleet · **Date:** 2026-11-20

## What was wrong

Two changes met in one gathered batch. `surfaces-from-the-home` added `bin/gimle/surfaces.py`, the one reader
of the operator's public URLs from `<home>/hodd/identity/services.yaml`. `gimle-move` (plan 335) removed the
`bin/gimle/` tree from Ymir and added `board-engine-guard.sh`, which refuses a new file under that path.
Both changes are right; together, the reader was a new file in a forbidden tree.

## What changed

The reader is not board-engine code. It answers "which public URL does this service have", which every fleet
needs. So it moved, with its test, to a function-named home (RULES/23):

- `bin/gimle/surfaces.py` → `bin/fleet/public-surfaces.py`
- `bin/gimle/tests/test_surfaces.py` → `bin/fleet/tests/test_public_surfaces.py`

The callers follow: `bin/gates/checks.d/0513-surfaces-from-the-home.sh`,
`systems/skirnir/services/learn-site.sh` and `systems/snotra/services/letters/letter-design.py`. The CLI is
unchanged (`--get`, `--list`, `--json`), and the test passes (7 of 7). The earlier fix note
`docs/fixes/gimle/2026-11-20-the-surfaces-come-from-the-home.md` stays as the record of where it was born.
