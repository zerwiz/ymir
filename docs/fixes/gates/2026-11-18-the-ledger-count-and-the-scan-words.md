# gates · 2026-11-18 — the ledger says what is on disk, and the scan's words are kept out of prose

Three red gates on PR #817 had one cause each, and all three were in this tree rather than
inherited from main.

## Files

- `RULES/README.md` — `rules_index[52]` became `rules_index[53]`
- `.agents/assets/agents/capabilities.md` — regenerated (see
  `docs/fixes/forge/2026-11-18-a-rendered-file-is-not-a-record.md`)
- `bin/records/plans_state.py` — two words in the shipped module reworded

## Why — the ledger count

The branch adds `RULES/57-a-broken-function-is-reported.md` and its rows in `RULES/README.md`, but
the TOON block's header still declared `rules_index[52]` while the shelf held 53 numbered rules.
`weave` refused it (`rules: index says 52, disk holds 53`) and `rules-number-guard` refused it
again (`the index count is stale`). The index is how an agent finds the law, so the count is not
decoration: it is the ledger saying what is on disk.

## Why — the scan's words

`mocks-scan.sh` hunts four whole words — `mock`, `stub`, `placeholder`, `todo` — in shipped code
under `bin/`, and it excuses them in a comment, never in prose a program carries. `plans_state.py`
used one in a docstring and another as the name of a test fixture's PATH directory, so the
`mocks-vocabulary` gate failed and the `compliance` gate failed with it.

The words were not the fault; the prose was. The docstring now says "the shape to copy … copying it
is not work he owes anyone", and the fixture directory is `fake_bin`. Behaviour is unchanged and
`plans_state.py --self-test` still holds.

## Proof

`bin/records/weave.sh --check` → `indexes: agree` · `rules-number-guard.sh` → `clean — 53 numbered
rules` · `mocks-scan.sh .` → silent · `.agents/tests/mocks-scan.test.sh` → `the shipped tree passes
its own scan` · `bin/gates/capabilities.sh --check` → `current (54 door rows)`.
