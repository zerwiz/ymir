# seat · unversioned · 2026-11-14 — the find door reads the work, not the tab

Plan 293 part 6. On 2026-11-14 the helm briefed the **wrong worker** because its tab title looked
right, and the Allfather had to stop it. That cost him a stop and a correction — and it produced the
runbook paragraph "find the right agent by its work, not its label", which was three shell pipelines
and a warning to skip your own pane. This makes it a door.

## Why

A tab title is what someone typed when the pane was opened. The screen is what the agent actually
knows. So the search must read recent output and name panes, and there are four ways to get it wrong:

1. matching the caller's own pane — the words it searches for are usually in its own scrollback,
   because the operator has just pasted them there;
2. matching a pane with no agent in it at all;
3. treating the query as a pattern, so `a.b` matches `axb`;
4. dropping a pane that could not be read, so "no match" and "could not look" are indistinguishable.

## What changed

`bin/seat/seat-find.sh "<words>" [--lines N] [--any] [--all] [--exclude <pane>]`:

- reads every pane that carries an agent (`herdr pane list` → panes with an `agent`), and prints one
  row per matching pane: pane, agent, status, which words matched, the last matching line, the title;
- **every word must appear** by default (`--any` for any of them), case is ignored, and each word is
  matched **literally** — a hook, not a regex;
- **skips the caller's own pane**, resolved from `HERDR_PANE_ID` or `herdr pane current`, and says so
  in the help line; `--all` includes it, `--exclude <pane>` skips one more;
- **names an unreadable pane** in the help line and counts it — a pane that cannot be read is not a
  pane that did not match;
- exit 0 when something matched, 1 when nothing did (with an honest empty table), 2 usage, 3 when
  herdr cannot answer at all.

## Files

- `bin/seat/seat-find.sh`
- `bin/seat/tests/test_seat_find.sh`
- `docs/features/find-the-agent-by-its-work.md`
- `docs/features/_catalogue/entries/02-115-find-the-agent-by-its-work.md`
- `bin/gates/ci-verify.sh`

## Verified

- `bin/seat/tests/test_seat_find.sh` — 13/13 against a stubbed `herdr` and a throwaway home: only the
  pane that printed the word is named; a bare shell pane is never searched; the caller's own pane is
  skipped and `--all` includes it; AND versus `--any`; a dot is a literal dot; an unreadable pane is
  named; an empty result is an honest `seat-find[0]` with exit 1; no words is exit 2.
- Live on this machine, 2026-11-14: `seat-find.sh "whole-tree"` named the one worker whose screen
  carries that phrase and nothing else, printed `help: own pane … was skipped — --all includes it`, and
  refused to name the bare-shell panes. An earlier live run with a colleague's name as the query was
  the reason the fault was found at all — and the reason the fixtures below carry an invented token:
  this repository is public and names no person (RULES/04).

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #752
- 2026-11-14 — the fixtures' name replaced by an invented token; the live proof re-measured rather
  than re-quoted
