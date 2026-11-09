# The window is exact, approximate, or unknown with a reason — and what waits carries its age

**2026-11-09 · component: seat · `bin/seat/core-four.sh` · `bin/seat/pending.sh`**

Two dials of the near loop lied by omission, in the same way: they painted an absence as a
number.

## The window was a zero when the truth was "unknown"

`core-four.sh` resolved the window from `~/.pi/agent/models.json`, then from the catalog, and
both failures collapsed into `window: 0`. The hall renders a non-positive number as `—`, so a
model the catalogue could not place looked exactly like a model with no window at all. Worse,
the catalog path parsed the human suffix with string surgery:

```
raw.replace("M","000000").replace("K","000").replace(".","")
```

which turns `65.5K` into **655,000** — ten times its true 65,500 — and `1.05M` into
105,000,000. A locally registered model hides this behind its exact `contextWindow`; an
**online** model has no registry entry, so the suffix is the only source and the fault lands
squarely there.

Now the door reports three states, and never a silent zero:

```
context{window,auto_compact_at,force_compact_at,known,approx,source,reason}
```

- **exact** — a provider registry names `contextWindow`;
- **approximate** (`approx: true`) — the catalog's rounded suffix;
- **unknown** (`known: false`) — `reason` names which door stayed silent, e.g.
  `no-such-model-xyz is not in this machine's catalogue — the catalogue answered nothing (no
  pi on this machine?)`.

The size parse is arithmetic: `K`=10³, `M`=10⁶, decimals kept (`65.5K` → 65500,
`1.05M` → 1050000, `131072` → exact).

## What waits carried no age, and cut paths in half

`pending.sh` set `since` only for pull requests, so 17 of 20 cards showed no age; and it cut
`what` at 90 characters, mid-path — `…/Documents/ymi` names nothing a hand can open.

Now a wake line's age is **the line's own** when it carries one (`at=2026-11-06T…`, or a run
id `ask-20261106T204447Z`), else the mtime of the shelf it names (a "report filed at /…/x.md"
line gets that file's real date), else nothing — never the queue file's mtime, which every
line shares and which would paint them all the same age. The cut is 160 characters, so a
shelf and a path survive whole.

## Proved

- `env -i PATH=$HOME/.bun/bin:/usr/bin:/bin bin/seat/core-four.sh --json` →
  `window 1000000 … known: true, approx: true, source: catalogue` (was `0`).
- A fictional model with no catalog and no `pi`: `known: false`, `window: 0`,
  `reason` present.
- `pending.sh --json` → 21 items, **10** now carrying a date (was 4), longest `what` 160,
  every path whole.

## Guard

`bin/seat/tests/test_doors_fleet_path.sh` (9 ok / 0 fail) asserts all of the above, with the
size parser checked directly against `65.5K`, `1M`, `1.05M`, `131072`.

## Note, not a claim

`bin/seat/tests/test_core_four_pending_factory.sh` reports **12 ok / 2 fail** here — the two
factory cases fail identically in `main` before this change (`factory-new: the home is
unresolved`). Pre-existing, unrelated, and named rather than quietly passed.

## CHANGE LOG

- **2026-11-09** — window states with a reason and an arithmetic size parse; pending ages from
  the record and whole paths (plan 229).
