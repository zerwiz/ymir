---
name: groa-update
description: >-
  Self-update a running Brokk and its eindri-homes to the latest from origin,
  through Gróa the updater shaman. Use when the Allfather invokes /updateBrokk
  (e.g. "/updateBrokk", "update Brokk", "pull the latest Brokk").
  Fast-forwards this Brokk repo's default branch and every local or remote
  Eindri-home through its guarded update path (never forced, never disruptive),
  then re-reads AGENTS.md and nudges each updated Eindri-home to do the same, so
  the whole tree runs the latest bin/ and instructions.
user-invocable: true
metadata:
  internal: true
---

# Gróa — updateBrokk

**Gróa** is the updater shaman — the *völva* who renews the tree. Brokk runs
her; **Galdr** owns the assets she must be reflected in when the instruction
surface moves; this skill is her door.

Self-update Brokk in place.
Brokk is its own repo, behind the same no-mistakes gate as any project, so new tracked material (`AGENTS.md`, `bin/`, `.agents/skills/`, and public `skills/`) reaches `main` and then sits there until each running Brokk pulls it.
Only `AGENTS.md`, `bin/`, and `.agents/skills/` are a running Brokk instruction surface; public `skills/` is installer-facing and is not loaded by Brokk.
This skill performs that pull for the running main Brokk and every Eindri-home, without disturbing any in-flight work.

The update is **fast-forward only** — the same sanctioned self-write as the fleet sync Brokk already runs.
For a remote route, it updates the configured Brokk code root on that host from its own origin, then guardedly fast-forwards the persistent home to that code-root commit.
It never forces, never creates a merge commit, never stashes, and advances a target only on a clean fast-forward; anything dirty, diverged, offline, or on the wrong branch is skipped and reported.
A tracked-files fast-forward leaves the gitignored operational dirs (data/, state/, config/, projects/, .no-mistakes/) untouched, so a Eindri-home's in-flight work is never disrupted.
This touches only the Brokk repo and its own worktrees, never anything under `projects/`.

> `bin/brokk-update.sh` is a back-compat alias; the updater is `bin/groa-update.sh`.

## What it does

1. **Run the updater (Gróa):**
   ```sh
   bin/groa-update.sh
   ```
   She fast-forwards this Brokk repo's default branch from origin, then updates every registered local or remote Eindri-home home through its placement-specific guarded path.
   She prints a `groa[1]` header, one status row per target (`updated` / `current` / `skipped: <reason>`), then the action lines:
   - `reread-Brokk: yes|no`
   - `galdr-reread: yes|no` — whether the instruction surface moved and Galdr's owning assets must be refreshed
   - `nudge-eindri-homes: <id> ...|none`

2. **Re-read AGENTS.md if your own instructions changed.**
   When `reread-Brokk: yes`, the tracked instruction surface (`AGENTS.md`, `bin/`, or `.agents/skills/`) just advanced under you.
   **Read `AGENTS.md` now** (CLAUDE.md is a real `@AGENTS.md` pointer to it) to refresh your operating instructions before doing anything else.
   When `galdr-reread: yes`, reflect the change in the owning Galdr asset in the same pass (the code/plan/asset agreement law).
   When both say `no`, nothing changed for you — skip the re-read.

3. **Nudge each updated live Eindri-home.**
   For every target on the `nudge-eindri-homes:` line (do nothing when it says `none`), send a one-line re-read nudge:
   ```sh
   BROKK_HOME=<this-Brokk-home> bin/brokk-send.sh <id> 'Brokk was updated to the latest — please re-read your AGENTS.md to pick up the new instructions.'
   ```
   Include `BROKK_HOME=<this-Brokk-home>` unless `BROKK_HOME` is already set to the active Brokk home.
   This is a gentle steer, not an interruption.

4. **Report to the Allfather in plain outcomes.**
   Summarize what landed without internal vocabulary: which parts of the fleet are now on the latest, and which were left as-is and why.
   Surface any skipped target whose reason needs the Allfather's attention (a home with un-landed changes, local edits).

## Safety

- **Fast-forward only.** Dirty, diverged, offline, or non-default-branch targets are skipped and reported, never forced or stashed. Nothing with unlanded work is ever discarded.
- **Only the Brokk repo and its worktrees** are touched, never `projects/`.
- **Eindri-homes are never disrupted** — a tracked-files fast-forward only when safe, plus a gentle re-read nudge when it changed.
- **When something is broken rather than outdated**, that is Eir's work, not Gróa's: `bin/eir-doctor.sh` diagnoses and mends.
