# fleet · 2026-11-20 — the room engine carries its owner label

## Files

- `bin/room/gladsheim-ensure.sh` — the engine's `docker run` adds `--label ymir.owner=gladsheim` and `--label project=gladsheim`

## Why

The house-chores errand listed every container on two machines and asked each one who owned it. On the
second machine, `gladsheim-engine` had no compose project and no owner label. Its mounts pointed into a
`/tmp/tmp.*` folder that no longer means anything, and it had exited four weeks earlier. Only a search of
this repository found the script that raised it.

Two laws ask for an owner on a container, and each names its own label:

| Law | Label | What reads it |
|---|---|---|
| the machine's container law (the operator's box contract) | a compose project, or `ymir.owner=<project>` on a lone `docker run` | a person, with `docker ps --filter label=ymir.owner=gladsheim` |
| the collaboration kit, `bin/collab/kit/RULES/23-containers-build-here-run-there.md` | `project=<project>` | `bin/collab/kit/scripts/kitlib/containers.py`, which filters on `label=project=<project>` |

`bin/records/running-inventory.sh` reads only the compose project label. A lone `docker run` has none, so
neither label makes the engine show an owner there; the labels make it findable by a filter, which is
what was missing when no one could tell whose call it was to remove it.

## Fix

`gladsheim-ensure.sh` labels the engine `ymir.owner=gladsheim` and `project=gladsheim` when it creates it.
The labels are applied only when the container is next created; Docker cannot add a label to a container
that already exists.

These are owner labels only. It is deliberately not `runtime.managed=true`: the nightly container
reap reads that label as "remove me when I have exited", which is right for a finished meeting bot and
wrong for a house service.

## Not done here

The stray `gladsheim-engine` and `gladsheim-element` on the second machine were not removed. They are
named in the errand's report for the operator to decide.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #873
- 2026-11-21 — rework for #873: the note cited a kit `RULES/21` and an `ymir.owner` reader that do not
  exist. It now cites the kit's real container rule (`RULES/23`) and reader, says plainly that
  `running-inventory.sh` reads only the compose project, and the engine also carries `project=gladsheim`.
