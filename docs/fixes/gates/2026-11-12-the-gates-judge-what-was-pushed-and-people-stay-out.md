# gates · 2026-11-12 — the gates judge what was pushed; people are private; units go through the register

## What was wrong

Seven faults in the wards and the delivery road (plan 272, faults 3, 7, 8, 9, 10, 11, 12).

- The rules ward charged a fork's sync of upstream files to the person who pushed it.
- A gathered batch could be squash-merged and lose each errand's history, and nothing said so.
- `fixes.sh validate` called 595 good notes invalid: it still demanded the first-ever note format.
- A real person's name and chat username sat in a public test, and no ward read people.
- An old checkout's `garmr.sh` could re-point a pinned unit.
- The `.arm.log` notice about `bin/syn-watch.sh` was an old record: the log's last write is 2026-10-12, before the 2026-10-24 fix.

## What changed

| Fault | Fix | Where |
|---|---|---|
| 7 fork sync | A file the push adds that is byte-identical to upstream's default branch is not the pusher's | `bin/gates/guards/rules-compliance-guard.sh` |
| 8 main's faults | Four classes whose history lives elsewhere are exempt, with reasons; 540 documents gained a CHANGE LOG, 29 scripts a shebang, 73 an exec bit | the same guard, one sweep commit |
| 9 squash | `gather-merge-guard.sh` names a gathered batch that landed as one parent; `gather-merge.yml` runs it on every push to main | `bin/gates/guards/gather-merge-guard.sh`, `.github/workflows/gather-merge.yml` |
| 10 validator | The validator asks what a reader needs: a titled, non-empty note | `bin/gates/fixes.sh` |
| 11 people | The NDA matcher and the people ward read collaborators, names and Telegram rosters; the fixture is fake | `ndalib.py`, `nda-guard.py`, `people-guard.sh` |
| 12 units | `unit_settle` hands every written unit to the pin's register; `unit-writer-guard.sh` names a writer that does not; `garmr.sh` no longer falls back to a tree | `bin/engine/unit-settle-lib.sh`, `bin/ward/garmr.sh`, `bin/fleet/fleet-ensure.sh` |

## What GitHub cannot do

The merge method is chosen at the click, from the repository's settings. No pull-request check can see it. The only lever before the click is turning "Allow squash merging" off in the repository settings, which is the owner's.

## What is still owed

- Old lines that already name a person are counted, not refused, on a whole-file read; a new line is refused at commit, push and write.
- 205 plain-HTTP or address lines and 27 rule headings in the whole tree are not swept: changing them rewrites a line, which RULES/06 forbids without a decision.
- An old checkout cannot be stopped from code it already carries; the register puts the unit back at the next update.

## CHANGE LOG

- **2026-11-12** — written with plan 272.
