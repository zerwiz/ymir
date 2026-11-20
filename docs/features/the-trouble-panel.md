# The trouble panel — the house tells you it is in trouble before you ask

**What it is.** `bin/ward/trouble.sh` reads, on one machine, the nine things that fail silently. When one of
them turns red, it sends you one line with buttons through the hotline (`bin/notify/send.sh`), and it stays
quiet otherwise. `trouble.sh fleet` shows a row per machine, and each row is measured on that machine.

**Why it exists.** On 2026-11-20 a full disk, three false *done* reports, ten unanswered questions, a failed
house watch and a pin twenty commits behind all failed the same way: nothing said a word until the operator
asked (plan 339).

**What you need.** A Ymir install with its home resolved. The machine needs `git` and `python3`; systemd,
herdr and Hyprland are read when they exist, and a signal whose source is absent says **SKIP** with its
reason, never a guess and never a red.

## The nine signals

| Signal | Red when | The line, and the variable that moves it |
|---|---|---|
| `disk` | a watched path is too full, or fills too fast. Garmr's own disk probe (`bin/ward/garmr/house.py`), where it is installed, also counts | 85 % used (`TROUBLE_DISK_PCT`) · 20 GiB a day (`TROUBLE_DISK_GROWTH_GIB`) · paths `TROUBLE_DISK_PATHS` (default `/`) |
| `guardian` | `housewatch.service` failed, its timer is not active, or it is not installed; or the hound's heartbeat is old | 600 s (`TROUBLE_HOUND_MAX_S`) |
| `pin` | the pinned runtime is too far behind `main`, for too long | 10 commits (`TROUBLE_PIN_BEHIND`) for 2 h (`TROUBLE_PIN_HOURS`) |
| `unpushed` | an `eindri/*` branch holds commits that are on **no remote**, and the oldest is old | 3600 s (`TROUBLE_UNPUSHED_S`) |
| `questions` | a file in `state/eindri-questions/` with no word sent to its errand since, and the errand not ended | 3600 s (`TROUBLE_QUESTION_S`) |
| `errands` | an errand is **dead** (no agent in its pane), **false-done** (a fresh `done:` with no commit since launch), or **stalled** (working, idle, silent) | stall 1800 s (`TROUBLE_STALL_S`) · a `done:` is judged for 6 h (`TROUBLE_DONE_HORIZON_S`) |
| `hyprland` | Hyprland reports a config error. Read through `bin/desktop/hypr.sh config check` where that door exists, else `hyprctl configerrors` | — |
| `tells` | a tell in the arm's wake queue is still waiting | 3600 s (`TROUBLE_TELL_S`) |
| `loops` | one branch took the same commit subject more than twice in an hour. Níðhöggr judges it (`bin/gates/nidhogg.sh commits`) | `LOOP_COMMIT_MAX` (2) · `LOOP_COMMIT_WINDOW` (3600) |

The lines are counsel until the Allfather seals them. Set your own in `$YMIR_HOME/config/trouble.env`
(for example `TROUBLE_DISK_PCT=80`); never in the code.

## Commands

```bash
bin/ward/trouble.sh                          # this machine's reading; exit 1 when a signal is red
bin/ward/trouble.sh read --json --only disk,questions
bin/ward/trouble.sh check --notify           # keep the reading, notify each signal that TURNED red
bin/ward/trouble.sh check --notify --dry-run # the same, the hotline told not to deliver
bin/ward/trouble.sh fleet                    # a row per heart, forge and dev machine in fleet.json
bin/gates/nidhogg.sh commits --repo ~/ymir   # the commit-loop verdict on its own
```

The timer `trouble-panel` (in `.agents/config/units.yaml`, every five minutes, roles heart, forge and dev)
runs `check --notify`. `bin/engine/units.sh write trouble-panel` seats it on a machine.

## What a notice looks like

One line at HIGH, naming the machine: *"host-a is in trouble — disk: / is 90.5% used (90.7 GiB free)"*, with
a button that does the next thing (*🧹 Show what fills the disk*) and *📋 Show every trouble row*. If more
than two signals turn red in one check (a first run, a machine back from the dark), they arrive as **one**
line that counts them. A signal that stays red is not said again; one that turns green and red again is news.

## Where the reading lives

`$YMIR_HOME/state/trouble/<host>.json` is the last reading, for a hall to render (Valaskjálf's rail, plan
334). Beside it: `<host>.disk.jsonl` (disk samples for the growth rate) and `<host>.since.json` (when a slow
signal first went bad). The home's `state/` is not committed.

## Limits

- **`fleet` asks over ssh**, using the `user` and `tailnet` in `hodd/data/fleet.json`. A machine marked
  `dark`, or without a road, is listed as not asked. A machine whose pin does not carry the panel yet is
  handed this reader in the ssh script and still measures itself with its own home resolver.
- **A question counts as answered** when the fleet message log (`state/fleet/messages.jsonl`) shows a word
  sent to that errand or its pane after the question was filed, or when the errand has ended since. A reply
  given some other way is not seen.
- **False-done is judged only on a fresh `done:`** written by the worker. The helm's sweep that closes an
  old errand is bookkeeping, not a report.
- **The hall rendering is not here.** This page's reader writes the JSON; drawing it on Valaskjálf is plan 334.

## If it does not work

- `error: the home is unresolved` — set `YMIR_HOME`, or run the install.
- A signal is `SKIP` — read its note: it names the missing source (no systemd, no pin, no Hyprland running).
- No Telegram line arrived — run `check --notify` by hand and read the `send.sh` decision it prints; a
  `duplicate` means the same key was already said this hour.

## CHANGE LOG

- 2026-11-20 — first page: nine signals, the notice on the turn to red, the fleet row (plan 339.5, 339.6, 341.4).
