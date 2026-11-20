## snotra · unversioned · 2026-10-20 — the record has one home

### What

The meeting system had an ear and a record skill but no contract between them: every
seat wrote wherever its script happened to point, and nothing could say whether a
meeting heard by the bot, the ear or a Þing room was the same kind of object.

This adds the four doors that make the contract real:

- `bin/time/snotra/snotra-store.sh` — `new|put|state|index|list|verify|path`. The lane
  is a directory; `workspace` must equal it; audio must be git-ignored; a record is
  append-only; `index.md` is generated, never hand-edited.
- `bin/thing/ping-room.sh` — raises MiroTalk on the machine the operator is on, with
  `local|tailnet|public` publishing and an exclusive `ping.zerwiz.org` claim.
- `bin/time/snotra/snotra-autojoin.sh` — reads Mánagandr's normalised events, decides
  which meetings Snotra joins, and dispatches the bot; dry-run unless `--apply`.
- `bin/time/snotra/snotra-bot.sh` — the Vexa API door, bot named **Snotra**, HTTPS
  required, key from the vault.

### Why

The plan (`svartalfaheim/…/plans/87-snotra-joins-the-room.md`) found that Vexa, the
ear and Þing all produce a transcript but none produced a *record*, and that a record
without a lane boundary is one query away from leaking personal meetings into company
exports. The lane-as-directory and the generated index are the fix.

### Verified

- `bash tests/run.sh` — **61 assertions**, four suites, all passing:
  store 20, ping room 16, auto-join 16, bot 9.
- The store was exercised with a temporary home: work and personal lanes, transcript
  and minutes states, overwrite refusal, lane-mismatch failure, audio ignore enforcement,
  index generation, JSON listing.
- Auto-join was exercised with eleven fixture events: join, declined, no link,
  personal-off, private, blocked title, restricted, all-day, Ping, Zoom, and the
  max-per-run cap.
- The bot was exercised against a local fake HTTP API: bearer token, `bot_name:
  Snotra`, platform and workspace in the payload, status and stop, and refusal of
  plain HTTP.
- Þing was exercised with a stub room: raise, status, url, stop, claim, refusal of a
  claim held elsewhere, release.

### Not verified

- No real Vexa endpoint, no real MiroTalk room, no real calendar: the network paths are
  covered by fixtures and stubs, not by a live meeting.
- No Syncthing hub and no git sync were exercised.
- No Utgard run; no PR.
