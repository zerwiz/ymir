# The house says it is in trouble before it is asked

**Date:** 2026-11-20 · **Component:** ward (`bin/ward/trouble.sh`, `bin/ward/trouble.py`) · **Plan:** 339.5,
339.6 and its two appended signal sections, 341.4 · **Errand:** `trouble-panel`

## What was wrong

On one day, on the dev machine, six things failed the same way: silently. The disk filled. Three errands
reported *done* with nothing behind them. Ten questions sat unanswered. `housewatch.service` failed and the
hound's heartbeat went an hour old. The pin stood twenty commits behind `main`. Nobody was told until the
operator asked. The evening added three more of the same kind: a Hyprland config error nothing reads, tells
to the arm nobody answers, and a judge committing the same change-log ten times to one pull request's branch.

## What was built

| File | Change |
|---|---|
| `bin/ward/trouble.py` | one reading per machine of nine signals: `disk` (85 % or 20 GiB a day, plus Garmr's `house.py` disk row where it is installed) · `guardian` (housewatch failed, timer down or not installed; hound heartbeat over 600 s) · `pin` (over 10 behind for over 2 h) · `unpushed` (an `eindri/*` branch with commits on no remote for over an hour) · `questions` (unanswered for over an hour, judged by the fleet message log) · `errands` (dead, fresh false-done, stalled) · `hyprland` (`hypr.sh config check` where it exists, else `hyprctl configerrors`) · `tells` (a signal row in the arm's queue older than an hour) · `loops` (Níðhöggr's verdict) |
| `bin/ward/trouble.sh` | the door: resolves the home and state through `hoard-lib.sh`, sources `config/trouble.env` for the operator's own lines |
| `check --notify` | keeps the reading at `state/trouble/<host>.json` and sends ONE HIGH line with buttons through `bin/notify/send.sh` for each signal that **turned** red; a red that stays red is quiet; more than two at once are one line |
| `fleet` | a row per machine (every role since the rework below) in `hodd/data/fleet.json`, each measured on that machine over its `user@tailnet` road; a machine whose pin lacks the panel is handed the reader in the ssh script and measures itself with its own resolver; a dark machine is not asked |
| `.agents/config/units.yaml` | the `trouble-panel` timer, every five minutes, roles heart, forge and dev (`all` since the rework below) — one register, never a hand copy per box (RULES/25) |
| `bin/ward/tests/test_trouble.sh` · `bin/gates/checks.d/0545-trouble-panel.sh` | the proof (32 assertions) and the gate that holds it |
| `docs/features/the-trouble-panel.md` · catalogue entry `00-114` | the how-to |

Read-only on the machine. It writes only its own three files under `state/trouble/`.

## The proof

```
$ bash bin/ward/tests/test_trouble.sh
… 32 × ok …
test_trouble: all passed
```

Two signals end to end on the dev machine, live, from this tree (the desk was free):

```
$ bin/ward/trouble.sh check --notify --only disk,guardian
  "<dev>","disk","RED","/ is 90.5% used (90.7 GiB free)"
turned red: disk, guardian · disk: send.sh exit 0 "send","ward","HIGH","1","1","1","1","1"; guardian: … "duplicate" …
$ bin/ward/trouble.sh check --notify --only questions
turned red: questions · questions: send.sh exit 0 "send","ward","HIGH","1","1","1","1","1"
$ bin/ward/trouble.sh check --notify --only questions,disk     # still red: nothing sent
```

The guardian line was suppressed as a duplicate because an earlier dry run in the same hour had used the
same hotline key. Dry runs now carry their own key (`…:dry`), so they can never silence a real notice.

`trouble.sh fleet` answered from three machines. On the heart it found `housewatch is not installed`, a
10-hour-old question, a stalled errand and 15 unanswered tells. On the second dev machine it found the disk
at 87.9 %, `housewatch is not installed` and a dead errand pane. The 339.6 gap is now a visible red, not a
silent one.

## Rework of PR #874 (2026-11-21)

The judge's three items were mended; see `docs/fixes/ward/2026-11-21-a-trouble-notice-is-retried-until-sent.md`.

## Not done here

- **The hall rendering.** The reading is JSON at `state/trouble/<host>.json`; drawing it on Valaskjálf's rail
  is plan 334.
- **The timer is registered, not seated.** `bin/engine/units.sh write trouble-panel` seats it once this change
  is in a release and the pin carries it.
- **The thresholds are counsel** until the Allfather seals them (plan 339, "What only he answers" 3).

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #874
