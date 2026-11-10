## vault · 2026-11-10 — the home is pulled before and pushed after (RULES/50)

### What

- **`bin/vault/home-sync.sh`** (new) — the one door for editing the home: `begin` (fetch + merge origin, refusing a
  real conflict with the names and leaving the tree as it was), `ship "<msg>" <paths…>` (begin, stage the NAMED paths,
  commit, push; on a lost race merge and retry up to 5 times, jittered; never force), `ship --dry-run`, `status`,
  `setup` (seats `merge.ours.driver`).
- **`bin/vault/push.sh`** — now a thin alias of `home-sync.sh ship`, so every older caller pulls first. It gains the
  `--dry-run` that `docs/features/the-home-push-door.md` already documented but the script never had.
- **Migration `0018-the-home-pulls-first`** — writes a marked block into the home's `.gitattributes`
  (`merge=union` for the runes, every `*.jsonl` log and the plan index; `merge=ours` for the learn-home mirror), seats
  the driver, ships the file, and seats Claude's Ymir doors. Runs on install, `/updateymir` and `eir-doctor fix`.
- **`RULES/50`** — the law.

### Why

On heimdall, 2026-11-10: one pull of the home met 1,077 conflicts (1,062 of them a generated mirror differing only by
`generated_at`), the next pull minutes later met two more, and one plan number was taken three times in an hour. The old
`push.sh` pushed without fetching, and the box contract said "committing is not pushing", so commits sat local while
every other seat and cron wrote on.

### Verified

- `bash -n` clean on all three scripts; `home-sync.sh status` prints `ahead 0 · behind 0 · dirty 0` on heimdall after
  the hand merge; `push.sh --dry-run` prints the named paths and touches nothing.
- The union rules were not yet exercised by a live two-seat race — the next real pull is that proof.

### Not done

Branch-and-PR for the home was considered and declined (RULES/50 §"Branch or main?").
