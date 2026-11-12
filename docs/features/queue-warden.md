# Queue warden

Gets every open PR into main automatically, or blocks with a named reason.

## Commands

- `bash bin/forge/queue-warden.sh run` — one pass over every open PR.
- `bash bin/forge/queue-warden.sh --dry-run` — report only.
- `bash bin/forge/queue-warden.sh --pr N` — process one PR.
- `bash bin/forge/queue-warden.sh --install-timer` — seat a 10-minute timer.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
