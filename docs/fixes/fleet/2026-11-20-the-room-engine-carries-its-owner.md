# fleet · 2026-11-20 — the room engine carries its owner label

## Files

- `bin/room/gladsheim-ensure.sh` — the engine's `docker run` adds `--label ymir.owner=gladsheim`

## Why

The house-chores errand listed every container on two machines and asked each one who owned it. On the
second machine, `gladsheim-engine` had no compose project and no owner label. Its mounts pointed into a
`/tmp/tmp.*` folder that no longer means anything, and it had exited four weeks earlier. Only a search of
this repository found the script that raised it.

The container law (`RULES/21` in the collaboration kit, and the box contract) says every container
carries its owner: a compose project, or `--label ymir.owner=<project>` on a lone `docker run`. Without
the label, the container watch reports it as unowned, and no one can tell whose call it is to remove it.

## Fix

`gladsheim-ensure.sh` labels the engine `ymir.owner=gladsheim` when it creates it. The label is applied
only when the container is next created; Docker cannot add a label to a container that already exists.

The label is the owner label only. It is deliberately not `runtime.managed=true`: the nightly container
reap reads that label as "remove me when I have exited", which is right for a finished meeting bot and
wrong for a house service.

## Not done here

The stray `gladsheim-engine` and `gladsheim-element` on the second machine were not removed. They are
named in the errand's report for the operator to decide.
