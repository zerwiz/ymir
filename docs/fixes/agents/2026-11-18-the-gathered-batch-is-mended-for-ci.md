# The gathered batch is mended for CI (PR #818)

**Date:** 2026-11-18. **Component:** agents (the seat road), records, installation doc.

## What broke

Pull request #818 gathered 21 stalled branches and 3 open pull requests. Its first CI run was red on three checks, and each was a fault of the merge, not of the branches:

| Check | Cause | Mend |
|---|---|---|
| `opencode-launcher` | Resolving a conflict by main's side kept the new seat logic in `bin/agents/eindri-start.sh` but dropped the lines that define `HERDR_INSTALLED` and `herdr_err`, so the file was half-applied. | The definitions are back. `YMIR_HERDR_PANES=0`, herdr's own switch for "no panes", now counts as herdr not being in use, so the tmux road stays reachable when the operator asks for it. |
| `compliance` (Rule 07) | `config/services.schema.json` carried example paths shaped like `/home/<user>/`. | The examples use `<heart-home>/`. |
| `capability` | The capability register was one batch behind the tree. | Regenerated with `bin/gates/capabilities.sh`. |

Also mended: two stacked headers in the install table of `installation.md` (`install[38]` and `install[36]`) left by a docs merge. The block now declares its true 39 rows.

## Why it matters

A conflict settled "by main's side" on a whole file can drop the definition a kept line depends on. The batch is now audited line by line against every branch it gathered, so dropped logic is found instead of assumed absent.

## CHANGE LOG

- 2026-11-18 — written with the mend of #818.
