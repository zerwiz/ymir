# agents · 2026-11-08 — a seat's own state is a seat, not a split house

## What

`bin/agents/einherjar-spawn.sh` refuses to start when `state`, `data` and `config` resolve to different
bases, and the reason it was written is sound: on 2026-10-06 one errand id came to own **two** Yggdrasil
worktrees because a partial override let the state dir and the data dir disagree.

But every seat now runs with its own state dir — `~/.local/state/ymir/seats/<id>` — while `data` and
`config` stay in the one home. The three-way check refused that, so **a seat could not spawn an Eindri or
seat a review judge at all**:

```
error: the house is split — state, data and config resolve to different bases.
  state: /home/…/.local/state/ymir/seats/atomic-runtime
  data:  /home/…/ymir/data
  config:/home/…/ymir/config
```

Measured on the atomic-runtime seat, 2026-11-08, when its own done line tried to seat Forseti.

## The change

The check now refuses **only** what the original fault was made of: `data` and `config` are one house,
always, and a disagreement between them is still a hard refusal. A `state` beside another base is named
aloud as a **seat** and allowed:

```
note: state is the seat's own (…/seats/atomic-runtime); data and config are one house (…/ymir) — a seat, not a split
```

Named aloud on purpose: a silent divergence is exactly what this guard exists to catch.

## Proved

```
$ BROKK_STATE_OVERRIDE=~/.local/state/ymir/seats/atomic-runtime bin/agents/einherjar-spawn.sh probe-seat <tree> --help
note: state is the seat's own (…); data and config are one house (…) — a seat, not a split
error: ship spawns require --mode <direct-PR|local-only|no-mistakes>     # it reached its own argument check

$ BROKK_DATA_OVERRIDE=/tmp/a/data BROKK_CONFIG_OVERRIDE=/tmp/b/config bin/agents/einherjar-spawn.sh probe-split <tree> --scout
error: the house is split — data and config resolve to different bases.  # the law still bites
```
