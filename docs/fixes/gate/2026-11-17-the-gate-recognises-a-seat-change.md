# The gate recognises a seat change, and the catalogue carries the failsafes

**2026-11-17 · component: gate · plan 001 §4 (the dead desk)**

## Two small things, both about a record that could not be seen

**1. `fixes-guard` had no component for a seat.** Its path map knew `bin/seat/verify-seat.sh` and nothing
else under `bin/seat/`, and nothing at all for `bin/voice/*`, `bin/engine/units.sh` or `config/units.yaml`.
So a correct note could describe a seat change and still cover nothing — the defect the same map fixed for
`bin/forge/*` and `bin/skuld/*` on earlier days. Three rows were added:

```
bin/seat/*|bin/voice/*|bin/engine/units.sh|bin/engine/units.py|config/units.yaml) echo runtime ;;
bin/notify/*) echo notify ;;
```

Adding a row is the mending, not a loosening: the note is still demanded, and it must now be judged
against what the change actually touched.

**2. The failsafes are in the catalogue.** `docs/features/the-desk-survives-a-death.md` is the page a
person reads, `docs/features/_catalogue/entries/02-118-the-desk-survives-a-death.md` is its row, and
`FEATURES.md` was **woven** from it (`bin/records/weave-features.sh` — never hand-edited, Rule 06).

## Proof

```
$ bin/records/weave-features.sh
wove FEATURES.md from 251 entries in 7 sections
$ grep -n "the-desk-survives-a-death" FEATURES.md
264:| The desk survives a death | Five failsafes so one OOM kill cannot take every agent … |
```

## CHANGE LOG

- 2026-11-18 — review-mend: added missing heading for #818
