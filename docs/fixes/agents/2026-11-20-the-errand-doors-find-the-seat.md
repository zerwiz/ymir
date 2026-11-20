# agents · unversioned · 2026-11-20 — the errand doors find the seat, not the name

Two doors could not find a **live** errand, and both were looking in the wrong place — one in the
wrong directory, one for the wrong kind of name.

## The two faults, as measured

**The reader looked in the checkout.** `ymir_errand read house-doors-small` answered

```text
errand[1]{id,status,backend,harness,model,worktree}:
  "house-doors-small","NOTHING RECORDED — no state/house-doors-small.meta and no .status"
```

while `state/house-doors-small.meta` and `.status` both stood in the **home** — the reader built its
path from the checkout (`<root>/state/<id>`), and the helm writes to `<home>/state/`.

**The sender asked herdr for a name it could not know.** `bin/agents/eindri-send.sh <id> "…"`
refused with *"no agent stands in `<id>` — herdr said: agent_not_found"* while the pane that held the
working agent was recorded in that errand's own meta (`seat_pane=w1D:p1`). An errand **id** is not a
pane; the record is the address.

`ymir_errand close` never had this fault, because it goes through `eindri-acclaim.sh`, which resolves
the home's state. That is the resolution both readers now use.

## What changed

- **`.pi/extensions/eindri.ts`** — `resolveHome()` reads `YMIR_HOME`, else `bin/vault/hodd.sh path`,
  and `errandStateDirs()` returns the order every shell door uses: `BROKK_HELM_STATE` →
  `BROKK_STATE_OVERRIDE` → `<home>/state` → the old in-tree `<root>/state`. `readErrand` takes its
  base from the first dir holding a record, prints the seat the meta names, and — when there is
  none — names **every** dir it looked in instead of one stale path.
- **`.agents/harness/opencode/plugins/ymir-tools.ts`** — the same three dirs, the same base, the
  same seat line, so the two harnesses cannot answer differently.
- **`bin/agents/eindri-send.sh`** — before it refuses, the door asks the record: an errand id is
  resolved to the pane its meta names (`seat_pane=`, else `window=`) and the brief is sent there,
  saying so on stderr. The TOON row still prints the pane column as the **destination**, so the
  record and the log agree.
- **`bin/agents/eindri-send.sh --resolve <id|pane>`** — answers "which pane does this mean?" with no
  herdr, no send and no stamp. It is the door a caller can ask before typing, and what the test asks.

## Proof

```text
$ bash bin/agents/tests/test_eindri_send.sh | tail -6
ok   an errand id is resolved to its recorded pane and the brief lands
ok   the row names the resolved pane, so the record and the send agree
ok   the resolution is SAID, not silent
ok   an errand whose recorded seat is empty is refused, and nothing is typed
ok   --resolve names the pane and the record it came from
eindri-send: 35 ok, 0 failed
```

The suite's stub herdr was taught the same fact the real one told us: **a pane id carries a colon**;
a target without one answered `agent_not_found` on 2026-11-20, which is exactly what made the fault
visible.

```text
$ bash bin/agents/tests/test_errand_doors_find_the_seat.sh
ok   the pi reader finds a record that lives in the HOME
ok   and it names the seat the record holds
ok   the helm override wins over the home, as the shell doors do
ok   a record that is nowhere is refused
ok   and the refusal names every dir it looked in
ok   the opencode reader resolves the same state dirs (helm, home, in-tree)
ok   the opencode reader no longer reads the checkout state by itself

errand doors: 7 ok, 0 failed
```

The pi reader is called for real through bun (a machine without bun runs the remaining cases and
says so by name). The opencode plugin needs the opencode runtime to load, so what is asserted there
is the **shape** the fault was made of — and the test says so rather than implying a live call.

On this seat, against the real records:

```text
$ bin/agents/eindri-send.sh --resolve house-doors-small
eindri-send[1]{target,pane,source}:
  "house-doors-small","w1D:p1","state/house-doors-small.meta"
```

## One note for whoever commits a change under `.pi/extensions/`

A Yggdrasil worktree **excludes** `.pi/extensions/` on purpose (Rule 13, plan 2026-10-24): pi loads
both the project tree and the seat's home, so a worktree carrying its own tree makes every tool name
collide. This errand edited one file there, so the path was checked out for the duration of the
commit and the exclusion put back after it — `bin/seat/valknut-load.sh --check` fails loudly while a
worktree carries a second tree, which is how the exclusion was verified restored:

```text
check{pi-extensions-one-home}:
  the worktree carries no second tree            PASS
```

## Files

- `.pi/extensions/eindri.ts` — `resolveHome`, `errandStateDirs`, the reader, the named dirs
- `.agents/harness/opencode/plugins/ymir-tools.ts` — the same resolution, the same seat line
- `bin/agents/eindri-send.sh` — `errand_pane`, the resolve-before-refuse, `--resolve`
- `bin/agents/tests/test_eindri_send.sh` — an errand id, a dead errand, and `--resolve`
- `bin/agents/tests/test_errand_doors_find_the_seat.sh` — the readers, by command
