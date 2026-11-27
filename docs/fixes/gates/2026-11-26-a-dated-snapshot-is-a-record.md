# A dated snapshot may name a retired path

**Component:** gates (retired-path guard)

## What was wrong

On 2026-11-23 and 2026-11-26 the retired-path guard refused the nightly ledger snapshot in the home. The
snapshot is a verbatim copy, and 21 lines in the copied documents named a retired home path.

## What changed

`bin/gates/guards/retired-path-guard.sh` exempts `hodd/saves/`. A snapshot is a dated record, and rewriting
it would falsify it. Every other new file is judged as before.

## Proof

`bin/gates/tests/test_retired_path_guard.sh` (gate `retired-path-snapshot`): the snapshot commits, and the
same text outside `hodd/saves/` is refused.

## CHANGE LOG

- 2026-11-26 — review-mend: added missing heading for #965
