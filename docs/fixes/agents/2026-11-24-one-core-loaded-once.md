# One contract core, loaded once, with every dated section folded in

**Component:** agents (plan 369, item 7) · also `RULES/06`, `bin/seat/`

## What was wrong

A Claude session in `~` loaded about 98,000 characters of instructions at start, and one inside a Ymir tree loaded
about 163,000. The contract (`AGENTS.md`, 66,426 characters, 1,019 lines) was pasted whole into the seat render
(`~/.claude/CLAUDE.md`). Inside a Ymir tree it was loaded a second time through the tree's `CLAUDE.md` (`@AGENTS.md`).
Half of each copy was dated sections correcting the other half. The Allfather: *"we loading crazy amount of
context. the append sections must be involved in the agents.md and not be appended, but involved in it."*

## What changed

- **RULES/06 first.** An appended section makes the contract a living document. A correction is folded into its topic,
  and the prior text is kept verbatim in `docs/contract-history/`.
- **History.** `docs/contract-history/AGENTS-2026-11-24.md` is a byte-for-byte copy of the old contract.
- **The core.** `AGENTS.md` is 119 lines and 8,587 characters. It holds who the agent is, naming the operator, the
  voice and the clarity law, the first law, delivery, Eindri-only workers, a decision table and a generated topic
  index.
- **Ten topic files** live under `.agents/assets/agents/contract/`, each opening with a `Read when:` line. Every dated
  section is folded into the topic it corrects. For example, the 2026-11-14 halls correction replaced the old login
  text, and the 2026-10-24 catalog law replaced the provider table.
- **The coverage check.** `bin/seat/contract-coverage.sh` lists 226 commands, paths, rule numbers, ports and plan
  numbers in the history copy. 223 are kept, 3 are waived by name in `coverage-allow.txt`, and none is lost. It also
  checks the core is at most 150 lines and that the index is current.
- **The render.** `bin/agents/seat-identity.sh --render` writes two files:
  - `~/.pi/agent/AGENTS.seat.md` holds the seat header plus the core, pasted, because pi, Codex, Cursor, Gemini and
    Hermes cannot follow an import;
  - `~/.pi/agent/CLAUDE.seat.md` holds the header plus `@~/ymir-runtime/AGENTS.md`, the pinned core, imported.
  `bin/seat/seat-surface.sh` links `~/.claude/CLAUDE.md` to the second file. `--check` still refuses a render that
  loses "Name him in every answer", and it checks that the import target carries the clarity law.
- **One copy inside a Ymir tree.** `bin/seat/harness-extensions-install.sh` adds the Ymir trees' own `CLAUDE.md` files
  to `claudeMdExcludes` in `~/.claude/settings.json`. That setting is supported by Claude Code 2.1.331 and is matched
  on absolute paths. Inside `~/ymir` the core then loads once, from the pin, as RULES/51 says it should.
  `~/ymir/CLAUDE.md` stays `@AGENTS.md`, so a developer without the seat still gets the core.

## Proof

- `bin/seat/contract-coverage.sh` prints `226,223,3,0,119,150` and "whole".
- `tests/test_seat_identity.sh` passes 15 of 15, with two new checks: the Claude seat file carries the header, and it
  imports the core exactly once.
- In a temporary home, `seat-surface.sh` and then `--check` passed every row, including "the Claude seat file imports
  the core once".
- Measured sizes:

| What | Before | After |
|---|---|---|
| `AGENTS.md` | 66,426 | 8,587 |
| the Claude seat file | 66,293 (pasted) | 1,636 + the imported core |

## Owed

- The live seat takes the new shape only after this merges, the pin moves, and the install runs `seat-surface.sh` and
  the hook installer.
- A fresh session in `~` and in `~/ymir` must then confirm four things: it names the operator, refuses a subagent
  spawn, finds the delivery gate, and finds the home-sync rule.
- The box notes (`~/CLAUDE.md`) are the other half of the plan and are rebuilt in the home.
- pi still loads a Ymir tree's own `AGENTS.md` beside its seat file, so it gets two copies inside a tree. It has no
  exclude setting, and that is left for a later change.

## The history copy and the retired-path guard

The verbatim copy quotes the old contract, which still names a retired home path (`hodd/life/`). Editing it would
break the copy, so `bin/gates/guards/retired-path-guard.sh` now treats `docs/contract-history/` as a record, like
`docs/fixes/` and `RULES/`. `bin/gates/tests/test_retired_path_guard.sh` checks it.

`bin/gates/guards/path-ledger-guard.sh` treats `docs/contract-history/` the same way, because the old contract names
paths that have since moved. `.agents/tests/path-ledger.test.sh` checks it.
