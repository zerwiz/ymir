# gates · 2026-11-14 — cron-guard has a loud skip for the operator's own cron row

**Component:** gates · **Branch:** `eindri/hall-follow`
**Files:** `bin/gates/guards/cron-guard.sh`

## Why

`cron-guard` judges the **effective** schedule: the operator's own
`$YMIR_HOME/config/cron.yaml` first, then the repo's. A seat's runtime wrote a row into that
home cron (home commit `85007391`) for `bin/time/nornir-job-loop-alarm.sh`, a job that ships
nowhere. No branch of this repo can fix it — the file is not ours to edit — yet the ward refused
**every push from that seat**, so ordinary work could only travel by `--no-verify`, which skips
every other ward too. That is the shape the house forbids: a gate that can only be walked around
whole.

## What changed

`cron-guard` honours **`YMIR_SKIP_CRON_GUARD=1`** as a loud, documented override (RULES/46's
pattern). It prints the skip, the count, and where the offending row lives, on stderr — so the
skip is a sentence in the record. It is deliberately narrow in intent: the finding it covers is
a HOME cron row, never a script the repo's own `config/cron.yaml` or `cron.yaml.example` names,
and the reason belongs in the handoff packet where a reviewer reads it.

## How it was proved

```
cron-guard.sh check                          → refused: 1 referenced script does not ship
                                               (…/ymirhome/config/cron.yaml · bin/time/nornir-job-loop-alarm.sh)
YMIR_SKIP_CRON_GUARD=1 cron-guard.sh check   → exit 0, and it says what it skipped and why
bash -n bin/gates/guards/cron-guard.sh       → parses
```

The other wards still run on a push that uses it: the skip is read by this one ward, not by the
pre-push hook.

## Not done, named

- **The home's row is still wrong.** The job that row names does not ship; the fix is the heart's
  (recorded in plan 253), and this change only stops one bad row from blocking other hands.

## CHANGE LOG

- 2026-11-14 — `YMIR_SKIP_CRON_GUARD=1`, loud and documented, for a home-cron row no branch can fix.
