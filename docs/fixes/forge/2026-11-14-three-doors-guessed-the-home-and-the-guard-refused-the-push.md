# forge · 2026-11-14 — three doors guessed the home, and the guard would not let the push through

## What happened

Pushing `eindri/kaia-to-volundr` was refused by the pre-push wards: `defaults-guard.sh` failed on
five lines. None of them were written by this errand — they were already in the tree — but the ward
judges the tree the push comes from, so the push could not proceed. The remedy is the one the ward
names: *call the resolver (`bin/vault/hoard-lib.sh`); never restate where things live*.

The five lines:

| File | Line | What it said |
|---|---|---|
| `bin/forge/smith-seat.sh` | 28 | `STATE="${_h:-$HOME/Documents/ymirhome}/state"` |
| `bin/forge/smith-seat.sh` | 96 | `stash_dir="${_h:-$HOME/Documents/ymirhome}/state/.seat-extensions/…"` |
| `bin/forge/verdict-watch.sh` | 24 | `STATE="${_h:-$HOME/Documents/ymirhome}/state"` |
| `bin/time/nornir-job-private-scan.sh` | 21 | `HOME_DIR="${YMIR_HOME:-$HOME/Documents/ymirhome}"` |
| `bin/time/nornir-job-private-scan.sh` | 53 | a detector row naming one machine's home literally |

A guessed home is not a small thing: it is the same value on the machine that wrote it and the wrong
value on the other three seats, and it puts a private path in a public tree (Rule 04, Rule 39).

## The mend

- `smith-seat.sh` and `verdict-watch.sh` take their state directory from **`hoard_state_dir`**, the
  resolver's own answer, and refuse in words when it cannot be resolved instead of guessing.
- `nornir-job-private-scan.sh` sources `hoard-lib.sh` and takes `HOME_DIR` from **`ymir_home_root`**.
- The scanner's detector row is now `/home/zerwiz[A-Za-z]*/` instead of one machine's literal home:
  it still catches the fleet's own paths, it names no user, and a character class cannot be mistaken
  for a path the door uses. (The scanner reports, it never fixes — the finding keeps its owner.)

## Proof

- `bash bin/gates/guards/defaults-guard.sh check` → `0`, `"none"` in all three blocks.
- `bash bin/gates/guards.sh` → exit `0`; the two remaining findings (`weave-guard`, `cron-guard`)
  are **INHERITED** — they name files this push did not touch, so they belong to main.
- Both doors still answer: `bin/forge/verdict-watch.sh --status` → `0` (`delivered … nothing delivered
  yet`); `bin/time/nornir-job-private-scan.sh --json` → `0` with its usual category counts.
- `bash -n` clean on all three scripts.

## Owed

`cron-guard` still reports five jobs in the operator's own `config/cron.yaml` naming scripts that do
not ship in the repo (`bin/fleet/registry-check.sh`, `bin/records/{gimle-tunnels-check,registries-refresh,
running-inventory,tunnels-registry}.sh`). They live in his home's `bin/`, and the scheduler runs from the
repo root — moving them into the repo or naming them absolutely is his call, not a smith's.

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #760
