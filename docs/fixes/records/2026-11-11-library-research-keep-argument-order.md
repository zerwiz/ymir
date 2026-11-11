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
