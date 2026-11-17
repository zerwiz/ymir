# Update loop

The heart keeps itself on latest main — and it **flips a proven release; it does not prove one**.

A candidate is proven **once**. The proof is a record in the machine's proof ledger
(`~/.local/state/ymir/proofs/<sha>.proof`, override with `YMIR_PROOFS_DIR`), written by whichever machine
actually ran the gate suite — the forge, a builder, or this machine the first time. Every later pass reads
the record, verifies its digest, and either flips the release or holds and says so. The same sha is never
proven twice.

## Commands
- `bin/engine/update-loop.sh check`
- `bin/engine/update-loop.sh run [--dry-run] [--window N]`
- `bin/engine/update-loop.sh status [--json]`
- `bin/engine/update-loop.sh decide [<sha|ref>]` — what the loop would do with that candidate, and why
- `bin/engine/update-loop.sh proof [<sha|ref>]` — the record for it, verified
- `bin/engine/update-loop.sh proof-record <sha|ref> --result pass|fail [--source LABEL] [--detail TEXT]` —
  record a proof taken elsewhere, so the heart only has to flip
- `bin/engine/update-loop.sh prove [<sha|ref>] [--force]` — prove it here, once, and record the outcome
- `bin/engine/update-loop.sh rollback [--to <sha>]`
- `bin/engine/update-loop.sh install [--dry-run]`

## What a pass says

| line | meaning |
|---|---|
| `LOOK,up to date,<sha>` | the running release is main; nothing to do |
| `PROVE,already-proven,<sha>` | a passing proof exists — the loop flips, and proves nothing here |
| `PROVE,already-proven,fail <sha>` | a failing proof exists — `HOLD`, exit 4, and **no build and no suite** for that sha |
| `PROVE,once,<sha>` | no proof yet: the suite runs once, in a git checkout, and the outcome is recorded |
| `FLIP,ok,<prev> -> <sha>` | the release is live |

The proof is recorded in both directions, so a red candidate costs one pass and not one pass per quarter
hour. `prove --force` is the deliberate re-run, and `proof-record … --result pass --source forge-builder` is
how a builder hands the heart something to flip.

## Limits
- The loop takes the machine's **heavy slot** (`bin/heavy-slot.sh`) for its whole pass, so nothing heavy
  runs beside it.
- The suite now runs in a **git checkout** of the candidate, never inside `~/ymir-releases/<sha>` — a
  release carries no `.git`, and a suite that asks git about its own tree was red there for that reason
  alone.
- A failing proof stops the repeat, not the redness: main stays red until something proves that commit
  green, or a later commit is proven.

## If it does not work
- Ask `bin/engine/update-loop.sh decide <sha>` first: it names the verdict and quotes the record.
- `bin/engine/update-loop.sh proof <sha>` prints the record field by field; a record that fails its digest
  is treated as no proof at all (it was edited after it was written).
- A pass that cannot prove says which log it left: `/tmp/ul-prove.log`, `/tmp/ul-build.log`,
  `/tmp/ul-flip.log`.

## CHANGE LOG

- **2026-11-10** — written with the change it describes.
- **2026-11-17** — a candidate is proven once; the loop reads a proof ledger, flips a proven release, and
  takes the heavy slot (plan 002 §6.1–§6.2).
