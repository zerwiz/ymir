# The claims ledger — one task, one seat

When several machines work at once, each task should be held by one seat. The claims ledger records who
holds what, in a place every seat can read. This page explains how to use it.

## What it is

A claim is a small file in your home, at `state/claims/<task>/<role>`. The home's git carries it, so a pull on
any seat shows it. `bin/agents/claim.sh` writes and reads these files.

A claim names a task by key:

| Task | Key |
|---|---|
| a pull request | `pr:<owner>/<repo>#<n>` |
| a plan step | `plan:<n>.<step>` |
| a branch | `branch:<owner>/<repo>:<name>` |

A claim also has a role: `coder`, `judge` or `shipper`. A judge and a coder may hold the same PR. Two coders may not.

## What you need

- A home that is a git repository with an `origin`, shared by your seats.
- Nothing else. `eindri-start.sh`, the review spawn and the push ward use it by themselves.

## The commands

- `bin/agents/claim.sh take pr:acme/app#12 --errand fix-12` takes a task, or refuses and names the holder.
- `bin/agents/claim.sh list --fleet` pulls the home and shows every seat's claims side by side.
- `bin/agents/claim.sh show pr:acme/app#12` says who holds one task.
- `bin/agents/claim.sh heartbeat pr:acme/app#12` keeps your claim fresh.
- `bin/agents/claim.sh release pr:acme/app#12` lets it go.
- `bin/agents/eindri-start.sh "<brief>" --id fix-12 --pr acme/app#12` claims the PR before the worker is seated.

## Limits

- A claim with no heartbeat for 2 hours is stale. It is offered, not stolen. Take it on purpose with `--adopt-stale`.
- A released claim stays in the home as `state=released`. Nothing is deleted.
- The push ward, `claim-guard`, refuses a push to a branch another seat holds as coder. `YMIR_SKIP_CLAIM_GUARD=1 git push` overrides it.
- The ledger is only as shared as your home. With no network, a claim is kept locally and says so.

## If it does not work

- *"is held — seat X, errand Y"*: another seat has the task. Ask them, or wait for the claim to go stale.
- *"claimed here but NOT shared"*: the home could not be pushed. Run `bin/vault/home-sync.sh ship` once the network is back.
- To skip the ledger for one errand, set `YMIR_CLAIMS=off`.

## CHANGE LOG

- 2026-11-21 — written with the change it describes (plan 343.12 and 343.14).
