# Broken register

A register of broken functions. Each finding is one append-only line.

## Commands

- `bin/seat/broken.sh add --function F --shows "cmd" --state open --closes "the proof"`
- `bin/seat/broken.sh list [--open] [--json]`
- `bin/seat/broken.sh close <id> --sha <sha>`
- `bin/seat/broken.sh count --class`

Data lives at `$YMIR_HOME/hodd/state/broken.md`, append-only. A close appends a closing line; it never rewrites the original.
## CHANGE LOG

- **2026-11-10** — written with the change it describes.
