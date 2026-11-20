# The local-only branches, gathered into one PR

**Date:** 2026-11-09 · **Component:** gate · **Branch:** `integrate/all-local-branches`

## What was wrong

A sweep of the checkout found **176 local branches**, of which ten carried commits that existed nowhere
on GitHub — 63 commits reachable from no remote ref, plus nine stashes. The rest were already
published; their remote branches had simply been deleted after merging, so the names were local-only
while the work was safe.

The ten, measured with `git rev-list <branch> --not --remotes=origin` and `git cherry origin/main`:

| branch | commits only local |
|---|---|
| `feat/one-door-for-the-registers` | 12 |
| `fix/hermes-knows-the-house` | 6 |
| `eindri/skills-mcp` · `feat/seat-wire` · `rule/human-readable-tables` | 2 each |
| `fix/collab-kit-clean` · `yggdrasil/plan-audit-prose-rows` · `feat/excalidraw-door` | 1 each |

`feat/gna-tells-the-arm` and `fix/the-sealed-vault-wins` were already in main by equivalent change
(`git cherry` marks them `-`), so nothing was lost there either.

## What was forged

One integration branch from current `main`, with all eight merged in (`--no-ff`, so every branch keeps
its own history and the merge records what came from where).

Almost every conflict resolved the same way, and the reason matters: **main was newer in every one**.
The branches were three days to a month old, and their features had landed by other roads in the
meantime — the register door, the seat wire's `nudge` verb, the home-by-resolver rule, the one
extension tree for a worker, the idempotent seat render. Taking main's side was not discarding their
work; it was recognising work that had already arrived by a different hand.

What the branches genuinely still carried was **their records**, and these are now in the PR:

- `RULES/38-the-answer.md` — an answer to the Allfather is prose, and on Telegram a decision is a button.
- `bin/gates/plan-audit.sh` — a prose row's status is read, not missed.
- `bin/skills/manifest.sh` — the index carries templates and requires.
- eight fix notes from the branches whose code had already landed.

## Verified

```
$ bash bin/gates/guards/rules-compliance-guard.sh check   # clean
$ bin/gates/guards/{inventory,registers,features,defaults,subsystem-docs,language,rules-number}-guard.sh check
  each: PASS
$ bash bin/gates/tests/test_skills_mcp.sh
```

The seven fix notes carried in by the branches were annotated with their own `## CHANGE LOG` (Rule 06
· R1) rather than left to fail the ward that had not existed when they were written.

## CHANGE LOG

- **2026-11-09** — the sweep, the merges, and the one PR.
