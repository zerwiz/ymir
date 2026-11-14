# records · 2026-11-11 — `library.sh research keep` failed on every call

## File
- `bin/records/library.sh` — the `research` branch

## What was wrong
It called `library.py research --root R keep …`; the Python door expects the subcommand first, so every
`library.sh research keep|list|show|…` printed `research: unknown subcommand ''` and kept nothing. RULES/35 (the
research is kept) could only be obeyed by calling the Python file directly — which is how the 2026-11-11 research on
mail and meeting records was kept.

## Fix
The subcommand is taken first and `--root` passed after it.

## Proof
`YMIR_RESEARCH_ROOT=$(mktemp -d) bash bin/records/library.sh research list` → exit 0 with an empty listing (was:
`unknown subcommand ''`).

## CHANGE LOG

- **2026-11-11** — written with the change (nidavellir, plan 250).

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: a dev machine. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
