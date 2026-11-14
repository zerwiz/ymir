# The leak ledger and the restart-storm ward

**Date:** 2026-11-14 · **Component:** ward · **Doors:** `bin/ward/soak-sampler.sh` · `bin/ward/restart-storm.sh` · **Plan:** 286 (P0, P4)

## What was wrong

Tonight showed the house paying for leaks it never measured. The heart ran out of memory
because two of its units restarted 2,277 times in two hours — one 1,283 times (its working
directory was gone), the other 994 — while every unit showed green. Sessrúmnir climbed to 1.5 GB and
froze. Each was found by accident, by a person reading a journal at the wrong hour.

Nothing in the tree recorded a service's memory, file descriptors, watches, children, GPU memory
or restart count over time, and nothing stopped a unit that was failing in a loop. Plan 286 P0
and P4 are those two things; this note is their building.

## What was forged

- **`bin/ward/soak-sampler.sh`** — one JSON row per house service and per app every five minutes,
  appended to `$YMIR_HOME/state/soak/services/<YYYY-MM-DD>.jsonl`. The timer (`--install-timer`)
  is a **user** timer, `ymir-soak.timer` → `ymir-soak.service`, running from the pin when the pin
  has the door and from its own tree otherwise (the unit records which). Nothing is installed on
  another machine by a worker (RULES/41, RULES/55): each machine's holder seats its own.
- **`bin/ward/restart-storm.sh`** — the ward. A unit strictly above `restart_storm.threshold`
  (default 10) inside `restart_storm.window_minutes` (default 60) is stopped, written as a
  `kind:"storm"` row into the same ledger, and sent through `bin/notify/send.sh` with its last
  error. The counts come from the journal's own `Scheduled restart job` lines; when the journal
  cannot answer, from the ledger's `NRestarts` deltas; failing both, from systemd's live counter.
  The row always says which source counted.
- **`config/soak.example.yaml`** — the shape of the knobs, shipped as an example. The values live
  in the home (`$YMIR_HOME/config/soak.yaml`), and `--status` prints both the value and whether it
  came from the config or the default.
- **`docs/features/the-soak-ledger.md`** and its catalogue fragment — the page a person reads
  (Rule 14).
- **Tests** — `bin/ward/tests/test_soak_sampler.sh` (23 checks over a planted process tree, cgroup,
  systemctl and nvidia-smi) and `bin/ward/tests/test_restart_storm.sh` (20 checks over a planted
  looping unit, journal and message door).

## How discovery stays generic

No list of our services is written anywhere. Services are the units **this machine installed** —
a unit whose `FragmentPath` is the distribution's is skipped (`sample.include_vendor: true`
measures them; nothing ever stops them). Apps come from the app registry (`ymir-app --list`) and
are matched to processes by their own command lines, so a clone, a worktree, a release and a
packaged install are all found by the same rule. An app registry that cannot be read writes a
`kind:"discovery"` row — an empty app list is never left looking like a quiet machine.

## What was measured here

- A pass on heimdall samples 39 targets (33 units, 6 apps) in about 2 seconds; rows carry the
  cgroup's whole process tree, so a worker's memory is counted toward the service that owns it.
- The hour of rows required by the plan, and the looping unit stopped and named, are in the
  errand's report at `$YMIR_HOME/state/eindri-reports/leak-ledger.md` (the ledger is machine
  state, not committed).

## Not done, deliberately

- **Nothing was enabled on another machine.** The heart's holder runs
  `bin/ward/soak-sampler.sh --install-timer` there himself, and sets `scope: system` in its own
  `soak.yaml` — the heart's house services are system units, and stopping one needs its
  privilege.
- **The app-side soak (`bin/gates/soak.sh <app>`, plan 286 P1/P2)** is a different errand; this
  one records the numbers, it does not drive an app through pages.
- **The Hlidskjalf Health view (P6)** is not touched.

## CHANGE LOG

- **2026-11-14** — written by the Eindri `leak-ledger` for plan 286 P0 and P4.

## Appended — what the live run taught (same day, 05:07 CET)

Measured on heimdall with a deliberately looping unit, after the note above was written. Three
facts worth keeping, because each changes how a row is read:

- **`NRestarts` resets when a unit is stopped.** The looping unit showed `NRestarts=28` while it
  was `auto-restart` and `NRestarts=0` the moment the ward stopped it. So a service row's
  `restarts` means *restarts since this unit last started*, not for ever — and the ward's own
  count for the window must come from the journal's `Scheduled restart job` lines, which is why
  that source is tried first. The ledger's deltas are the fallback, and a stop resets the
  baseline, which the delta reader handles by treating a lower number as a new baseline.
- **A stopped unit stops producing rows.** With no main pid, `Restart=always` and a counter of
  zero, there is nothing to measure, so the sampler leaves it out — the storm row is its record.
  That is deliberate: a machine that keeps printing forty zero rows about a unit it has just put
  down is a ledger nobody reads.
- **The ward reads the ledger without the sampler having to be up.** With `journalctl` blinded
  (the test's stand-in exits 1), the planted ledger rows (3 → 15 restarts inside the window)
  were counted, the unit was stopped, and the storm row carried `"source":"ledger"`.

The proof run itself: `ymir-soak-test-loop.service` (a two-second `Restart=always` loop)
restarted 28 times, was counted from the journal, was stopped by a `restart-storm.sh --pass`,
and the message door was handed
`--source ward --severity HIGH --message "restart storm: ymir-soak-test-loop.service restarted
28 times in 60 min (limit 10) — stopped; last error: … Failed with result 'exit-code'."`, with
`--no-telegram` for the test so a planted fault did not page the Allfather. The storm row in the
ledger carries the same facts.

## CHANGE LOG

- **2026-11-14 05:07** — appended after the live proof: the counter's reset, the stopped unit's
  silence, and the ledger fallback, all measured.
