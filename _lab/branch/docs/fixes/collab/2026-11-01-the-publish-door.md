# 2026-11-01 — publish: the baton becomes cards on the Board

**Component:** collab (Vingólf) · **Door:** `bin/collab/publish.py` (`collab.sh publish`) · **Plan:** 154

## Why

Plan 154's phase 4 is "the Board and the repo agree — one card per open PR and per decision, written by the
projector, never by hand". The repo shelf is checked and versioned; the Board is where a partner looks. Without
this, the baton is true and invisible.

## What it does

`collab.sh publish <repo>` reads `handoff/CURRENT.md` §3 (what is next) and §4 (what is blocked, and on whom) and
creates one card per item in a named Plane project, **idempotently by title**: a title already on the Board is
skipped, so a second run adds nothing.

## The three things it refuses

1. **A guessed project.** It matches the project by name or identifier, and when nothing matches it names every
   project that exists instead of creating one. A Board place is a decision, not a side effect.
2. **A database write.** It goes through Plane's own API, so the card appears in Plane's activity log, its
   validation runs, and its webhooks fire. The database-poking `gimle-board.sh create` stays a dry run for exactly
   this reason.
3. **A secret in a file.** The token is read from the vault by its one door (`hodd-set.sh --get PLANE_API_TOKEN`).

## Measured

- `Inmost-ControlTower`'s baton yields **9 cards** (5 next, 4 blocked) — and the parser needed ordered lists as
  well as bullets, because a baton's "what is next" is usually numbered.
- The project guard printed the whole Board rather than guessing: `AIGeeks Freaks, AssetVault, ChatCollab, Command,
  Courses Astro teaching site, Gimle, Hlidskjalf, Hlidskjalf Mobile, Moved to WayOf, Sessrúmnir, Smíðja factory,
  The Book — Hidden Knowledge Workshop, Ymir, Ymir Home Hodd, Ymir Homepage, whynotproductions, Óðrerir`.
- **Cloudflare answers 1010 to a bare `Python-urllib` agent** on `board.zerwiz.org`; a plain `User-Agent` is the
  whole fix. A 403 that looks like an auth failure was a bot check.

## Owed

`PLANE_API_TOKEN` is in the vault (94 keys, backup taken). The Board has no `Inmost-ControlTower` project — creating
one is the Allfather's call, and until it exists the door prints the list and stops.
