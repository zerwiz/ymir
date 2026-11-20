# The living-rail resolver walked one level short, and refused a path that could never exist

**Dated:** 2026-10-07 · **Component:** runtime (the living rail) · **Branch:** `eindri/snotra-live-tail`
**Found on:** heimdall (16,384 MiB, llama.cpp router on `:8080`)

## The symptom

Every rail-model resolution on this seat refused:

```
error: the fleet module is missing at /home/heimdall/ymir/bin/src/ymir_runtime/fleet
help: this tree predates the living rail resolver — update it
```

and the meeting summarizer wrote its minutes with the summary never filled — the
minutes carried `_(pending AI summary)_` where the rail's answer should be.

## Why the message pointed at the wrong thing

`bin/model/rail-resolve.sh` resolves the repo ROOT as one level up from its own
directory:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # <repo>/bin/model
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}" # -> <repo>/bin
```

The script lives at `<repo>/bin/model`, so the root is **two** levels up. `..`
walks to `<repo>/bin`, and the guard that follows then asks for

```
$ROOT/src/ymir_runtime/fleet     ->  <repo>/bin/src/ymir_runtime/fleet
```

a path that **cannot exist** — the fleet module lives at
`<repo>/src/ymir_runtime/fleet`, and it was there all along.

The refusal was truthful about the path it looked at, which is exactly why it
read as a missing module rather than a broken root: the error named a real
directory that was never going to hold anything. "This tree predates the living
rail resolver" sent the reader looking for an old checkout.

## The mend

One level became two:

```bash
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
```

`BROKK_ROOT_OVERRIDE` still wins, so a packaged or unusual layout keeps its own
answer.

## Proof

```bash
bash bin/model/rail-resolve.sh resolve --json
```

answers with the serving box, its URL, the key reference and the alias list —
before the mend it refused on every call.

## What this cost, honestly

Any caller that resolved a rail model through this door — the meeting
summarizer among them — had been falling back to whatever else it knew. The
summaries that did appear came from paths that did not consult the resolver at
all. This is why the live tail's rail-model resolution now **prefers the seat's
recorded choice** (`SNOTRA_RAIL_MODEL`, then the systemd drop-in) over the
resolver's first entry: on this seat `models[0]` is `apodex-1.0-mini` (21.7 GB,
~36 s) against the summarizer preset's ~5,864 MiB / ~15 s, which is the same
trap the 2026-10-01 ear note records.

## Not verified

- No regression test covers `rail-resolve.sh`'s ROOT resolution; one should, and
  this fix note is the record of why it matters.
- The resolver's own failure modes (a genuinely absent module, a bad
  `YMIR_FLEET_REGISTRY`) were not re-exercised after the change.