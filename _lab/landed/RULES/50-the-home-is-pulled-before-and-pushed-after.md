# 50 — The home is pulled before and pushed after

**An edit to the home begins with a pull and ends with a push, through one door — and the records merge themselves.**

Written 2026-11-10 at the operator's word: *"before edits can happen in ymir home we need to pull first and push
directly after the edits. we are getting collisions too often."* Measured that hour on heimdall: one pull of the home
met **1,077 conflicts** (1,062 in a generated mirror that differed only by a timestamp, the rest in append-only
records); the next pull, minutes later, met two more; and one plan number was taken **three times** by three seats.
Rule 45 (*start on the latest*) said a base is fetched, not remembered — but the home had no door that did it, and
the box contract said "committing is not pushing", so commits sat local for hours while every other seat wrote on.

## The law

```
laws[6]{rule,why}:
  "BEGIN WITH A PULL","bin/vault/home-sync.sh begin fetches and merges origin before any edit; a stale home is how a number gets taken twice"
  "END WITH A PUSH","bin/vault/home-sync.sh ship commits the NAMED paths and pushes at once — a commit left local is a collision deferred, not avoided. This supersedes the box contract's 'committing is not pushing' for the home (append-only: that line stays as the record)"
  "A LOST RACE RETRIES, NEVER FORCES","when another seat pushed first, ship merges and retries (5 tries, jittered); it never force-pushes and never rewrites a pushed commit (Rule 45)"
  "RECORDS MERGE BY UNION","append-only files (the runes, every *.jsonl log, the plan index) carry merge=union in the home's .gitattributes, so two seats' appends merge without a person (Rule 06)"
  "GENERATED FILES ARE REGENERATED, NOT RESOLVED","a mirror its own door rebuilds (the assistant shelf from learn-home) carries merge=ours; the next run re-stamps it"
  "A REAL CONFLICT IS REFUSED WITH THE NAMES","when two seats changed the same lines of a hand-written file, the door aborts the merge, leaves the tree as it was, and names the files — never a silent pick"
```

## Branch or main?

**Main, directly.** The home is a single-owner data repository written by machines every few minutes; a pull request
per cron write would bury the operator in reviews and would *defer* collisions rather than prevent them. GitHub's own
guidance for automated writers on a shared branch is the shape above: short-lived local work, fetch-merge-push, retry
on a rejected push. The public repo keeps its delivery gate (every change by PR, the Allfather seals); the home does not
need one, because nothing in it ships to a user.

## Numbers

A number (a plan, a rule, a ticket) is an allocation. Allocate it **after** `begin`, through its own door
(`bin/records/plan.sh next`, which refuses on a stale ledger), and `ship` the file that claims it in the same minute.

## Seated by

- `bin/vault/home-sync.sh` — the door (`begin · ship · status · setup`); `bin/vault/push.sh` is now a thin alias of
  `ship`, so every older caller pulls first without being repointed.
- Migration `.agents/migrations/0018-the-home-pulls-first.sh` — writes the marked merge-rules block into the home's
  `.gitattributes`, seats the `ours` driver, and ships it. Run by `ymir-install.sh`, `/updateymir` (Gróa) and
  `eir-doctor fix`, so every seat gets it on install and on update.
