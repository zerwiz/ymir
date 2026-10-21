# The house could write letters but not read them

**Component:** people · **Seat:** heimdall · **Date:** 2026-10-21

## What was wrong

Two letters went to a prospective collaborator — an introduction and a technical read — through a door that
**sends** (`bin/time/snotra/mail-send.sh`). If he answered, nothing in the house would have known:
there was no read door for people's mail, and the only Gmail read path in the tree belonged to the
meeting sign-off flow, scoped to a meeting's participants.

**So the honest answer to "can we see it if he replies?" was: not unless someone went looking.**

## What now exists

- **`bin/people/inbox.sh`** — the read door: `--from`, `--to`, `--unread`, `--days`, `--limit`,
  `--body`. Read-only; it never sends, marks or deletes. It uses the grant already in the vault, the
  same one the calendar write door uses, so no new consent was needed.
- **`bin/people/inbox-watch.sh`** — the watcher: every person in the registry with an address and
  consent, once a run. A new message is a Rune (`REPLY from <id> <address>: <subject>`), a desktop
  line, and a phone message through the hound's own severity ladder. Announced ids live in
  `$YMIR_HOME/hodd/state/people/inbox-seen.json`, so a reply is spoken once and a quiet run is
  quiet.
- **The schedule**: `config/cron.yaml` runs it at **08:20 · 14:20 · 19:20** — `@dev`, which is the
  role that holds the mailbox grant.

## Proved, not promised

`inbox.sh --to <that address> --days 1` returned **both letters we sent today**, with their
real message ids, timestamps, subjects and snippets — so the read path works end to end, and the
watcher's `--dry-run` reported `one registry entry … 0 new` (nothing from him yet, correctly).

## What is still a human's

The answer. The watcher says a reply arrived; drafting the reply is `collaborators.sh email`, and
the send is a word from the Allfather. A machine that answers a client on its own is not a feature
this house wants.
