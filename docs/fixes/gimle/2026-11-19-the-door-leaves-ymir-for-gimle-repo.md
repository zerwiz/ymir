# The MCP door leaves Ymir for Gimlé's own repository

**2026-11-19**, at the Allfather's word: *"all gimle things in gimle. everything in their own repos. we also
need to push the new apps to their repos."*

## What moved, and why

The Gimlé MCP door — `gimle-mcp.py`, `gimle_oauth.py`, the Dex shelf and their two test suites — was built
inside this repository's `bin/gimle/mcp/`. It is the hall's own code, and Gimlé has its own repository
(`github.com/zerwiz/gimle`). So the door leaves Ymir's pull request and travels to `zerwiz/gimle`, where the
hall's code belongs.

This is a placement correction, not a deletion: every file was copied first to the private home at
`hodd/reference/ymir-moved/mcp-door-2026-11-19/` (fourteen files, including the two fix notes as the review
left them), and the removal is recorded in `hodd/memory/deleted-on-purpose.log` with its reason.

## What did not move

The rest of this pull request is Ymir's own machinery and stays: the apps-home installer (`bin/apps/apps.py`),
the desktop launcher and the Electron library (`bin/desktop/`), the release door (`bin/engine/release.sh`),
the seat's watch and arm fixes, the Snotra cron and the learn-home cap. An app's *code* lives in the app's
repository; Ymir keeps the machinery that installs, launches and supervises it.

## What this leaves owed

- A pull request in `zerwiz/gimle` carrying the door, its tests and its docs.
- The new apps' own repositories pushed to the branches the split left them on (`smidja`, `odrerir` and
  `sessrumnir` sit on `split/from-ymir` because their `main` is protected; `hvergelmir`, `bilskirnir` and
  `rodd` carry the split on `main`).
