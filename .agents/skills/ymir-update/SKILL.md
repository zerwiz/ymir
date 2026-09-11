---
name: ymir-update
description: >-
  Self-update a running Brokk and its eindri-homes to the latest from origin.
  Use when the Allfather invokes /updateBrokk (e.g. "/updateBrokk", "update Brokk", "pull the latest Brokk").
  Fast-forwards this Brokk repo's default branch and every local or remote Eindri-home through its guarded update path (never forced, never disruptive), then re-reads AGENTS.md and nudges each updated Eindri-home to do the same, so the whole tree runs the latest bin/ and instructions.
user-invocable: true
metadata:
  internal: true
---

# updateBrokk

Self-update Brokk in place.
Brokk is its own repo, behind the same no-mistakes gate as any project, so new tracked material (`AGENTS.md`, `bin/`, `.agents/skills/`, and public `skills/`) reaches `main` and then sits there until each running Brokk pulls it.
Only `AGENTS.md`, `bin/`, and `.agents/skills/` are a running Brokk instruction surface; public `skills/` is installer-facing and is not loaded by Brokk.
This skill performs that pull for the running main Brokk and every Eindri-home, without disturbing any in-flight work.

The update is **fast-forward only** - the same sanctioned self-write as the fleet sync Brokk already runs.
For a remote route, it updates the configured Brokk code root on that host from its own origin, then guardedly fast-forwards the persistent home to that code-root commit.
It never forces, never creates a merge commit, never stashes, and advances a target only on a clean fast-forward; anything dirty, diverged, offline, or on the wrong branch is skipped and reported.
A tracked-files fast-forward leaves the gitignored operational dirs (data/, state/, config/, projects/, .no-mistakes/) untouched, so a Eindri-home's in-flight work is never disrupted.
This touches only the Brokk repo and its own worktrees, never anything under `projects/`.

## What it does

1. **Run the updater:**
   ```sh
   bin/brokk-update.sh
   ```
   It fast-forwards this Brokk repo's default branch from origin, then updates every registered local or remote Eindri-home home through its placement-specific guarded path.
   It prints one status line per target (`updated <old>..<new>` / `already current` / `skipped: <reason>`), followed by two action lines that tell you exactly what to do next:
   - `reread-Brokk: yes|no`
   - `nudge-eindri-homes: fm-<id>...|none`

2. **Re-read AGENTS.md if your own instructions changed.**
   When the updater printed `reread-Brokk: yes`, the tracked instruction surface (`AGENTS.md`, `bin/`, or `.agents/skills/`) just advanced under you.
   **Read `AGENTS.md` now** (CLAUDE.md is a real `@AGENTS.md` pointer to it) to refresh your operating instructions before doing anything else, so you are acting on the new instructions rather than the stale ones you were started with.
   When it printed `reread-Brokk: no`, nothing changed for you - skip the re-read.

3. **Nudge each updated live Eindri-home.**
   For every target listed on the `nudge-eindri-homes:` line (do nothing when it says `none`), send a one-line re-read nudge so that Eindri-home picks up its new instructions too:
   ```sh
   BROKK_HOME=<this-Brokk-home> bin/brokk-send.sh <id> 'Brokk was updated to the latest - please re-read your AGENTS.md to pick up the new instructions.'
   ```
   Include `BROKK_HOME=<this-Brokk-home>` unless `BROKK_HOME` is already set to the active Brokk home.
   This is a gentle steer, not an interruption: the Eindri-home already got a safe tracked-files fast-forward, and the nudge never forces, tears down, or discards its work.
   A Eindri-home that was skipped, already current, or has no live metadata is not on the list and needs no nudge.

4. **Report to the Allfather in plain outcomes.**
   Summarize what landed under `AGENTS.md` section 9 without Brokk's internal vocabulary: which parts of the fleet are now on the latest, and which were left as-is and why.
   For example: "Allfather, Brokk and both Eindri-homes are now on the latest."
   Surface any skipped target whose reason needs the Allfather's attention - for instance a home with its own un-landed changes (diverged) or local edits (dirty), which were left untouched on purpose.

## Safety

- **Fast-forward only.**
  A target that has diverged, is dirty, is offline, or is on a non-default branch is skipped and reported, never forced or stashed.
  Nothing with unlanded work is ever discarded - this is prime directive #3.
- **Only the Brokk repo and its worktrees** are touched, never `projects/`.
  It is the same sanctioned self-write as the fleet sync.
- **Eindri-homes are never disrupted.**
  A local or remote Eindri-home gets a tracked-files fast-forward only when its own checkout is safe to advance, plus a gentle re-read nudge when it changed.
  It is never torn down, interrupted, or forced.
