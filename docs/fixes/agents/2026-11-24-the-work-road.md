# The work road: one path from an ask to a merged change, with a mode and a model per role

Date: 2026-11-24 · Component: agents (work road) · Plan 365 (with Huginn H1 and H4)

## What was wrong

The pieces existed (Mjölnir, dispatch, the judge, the merge door, the release engine) but nothing joined them. Workers were started by hand, nothing fed Mjölnir, the heart could not run a worker, a user could not choose where the road runs or which models do the work, and the judge could share the worker's model family.

## What changed

- `ymir work` (`bin/fleet/work.py`): mode (`solo`, `fleet`, `offline`), models per role, `resolve`, `send`, `intake`, `dedupe`, `init`. One config, one resolver: the dispatch config gains `mode`, `roles`, `modes`, `merge` and `intake` (schema updated).
- The judge comes from the same resolver when a profile was chosen, and is refused when it shares the worker's model family (`bin/agents/eindri-review-spawn.sh`).
- Merge tiers: `bin/forge/merge-tier.py`, called by `bin/forge/judge-merge.sh` before any seal. T0 merges, T1 only when switched on, T2 waits for the Allfather.
- `ymir release npm <x.y.z>` (`bin/forge/npm/release-npm.sh`): the npm runbook as one door, dry run unless `--yes`, token read from the sealed hoard and never printed.
- `ymir install` asks the mode and models once (`step_work`); defaults are `solo` and free models.
- H1: every errand brief tells the worker to ask `ymir_research` before reading, and a kept answer under a week old is reused with no web call (`bin/mcp/figures.py`). H4: every research call records a row in `state/research-saving.jsonl`; `ymir work` totals it.
- Page: `docs/features/the-work-road.md`.

Proof: `python3 tests/test_work_road.py` and `python3 tests/test_nornir_status.py`.

## CHANGE LOG

- 2026-11-24 — review-mend: added missing heading for #924
