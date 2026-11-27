# Contract history

This folder keeps the **verbatim** text of the always-loaded contract (`AGENTS.md`) each time it is rebuilt.

## Why it exists

The contract is a living document (RULES/06, appended 2026-11-24). A correction is folded into the topic it
corrects, so the live text states the current truth once. The text it replaced is kept here, whole, with its dated
sections intact. Nothing is lost; it is only no longer loaded at the start of every session.

## The rules for this folder

- A file here is a copy taken **before** a rebuild, named `AGENTS-<date>.md`. It is never edited.
- `bin/seat/contract-coverage.sh` reads the newest copy. It fails when a command, path, rule number, port or plan
  number in it appears nowhere in the live core (`AGENTS.md`) or its topic files
  (`.agents/assets/agents/contract/`). A deliberate retirement is named in
  `.agents/assets/agents/contract/coverage-allow.txt`, with its reason.

| Copy | Taken | Why |
|---|---|---|
| `AGENTS-2026-11-24.md` | 2026-11-24 | plan 369 item 7: the 1,019-line contract became a 120-line core and ten topic files |
| `AGENTS-2026-11-26.md` | 2026-11-26 | plan 381: an answer goes back the way it came; main's core at `d0d5e2cca` and the replaced `workers-and-dispatch.md` mandate |

## CHANGE LOG

- **2026-11-25** — written with the first rebuild of the contract (plan 369 item 7). The copy was refreshed to
  main's text the same day, so it carries the Hermes section appended that morning.
- **2026-11-26** — appended the row for `AGENTS-2026-11-26.md` (plan 381).
