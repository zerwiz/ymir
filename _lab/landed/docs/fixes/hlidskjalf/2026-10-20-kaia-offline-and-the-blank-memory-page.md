# Kaia was "offline" because the service could not find `pi`, and the Memory page was blank because two shapes never met

**Date:** 2026-10-20 · **Component:** `hlidskjalf` (the Smíðja visualizer's server) · **Rule:** 07 (nothing hardcoded), 14 (a feature has a page)

## Fault 1 — `Executable not found in $PATH: "pi"`

`smidja.service` is a systemd **user** service. Its unit carries

```
Environment=PATH=%h/.bun/bin:/usr/bin:/bin
```

and pi installs to `~/.npm-global/bin/pi`. So the visualizer's orchestrator chat spawned a bare
`"pi"` that the service PATH could not resolve, every message 500'd, and the UI said **"Kaia is
offline"** — for a perfectly healthy memory bridge.

**Mend.** `server/model-catalog.ts` gains `piPath()`, resolved in a documented order: `YMIR_PI_BIN`
→ `PI_BIN` → `PATH` → the install locations a bare npm prefix produces (`~/.npm-global/bin`,
`~/.local/bin`, `/usr/local/bin`, `/opt/homebrew/bin`, `/usr/bin`). A path that does not exist is
**skipped, not trusted** — a stale override must never win over a real binary. `piCommand()` uses
it, so the chat, the model catalog and every future spawn agree.

## Fault 2 — the Memory page was blank

The UI's published contract (`shared/types.ts`) is nested: `db`, `counts.{episodes,facts,entities,
edges}`. The bridge answers **flat**: `store`, `episodes`, `facts`, `entities`, `edges`. The proxy
passed the bridge body through untouched, so `inspect?.counts.episodes` threw during render — and a
throw in a Vue render is a **blank page with no error**, which is why it looked like "no data"
rather than "a bug".

**Mend.** `server/memory-adapt.ts` — one translation, at the one boundary. It never drops a field
the bridge sent, never overwrites a `counts` that already exists, and never invents a number that was
absent (`0` is honest; a guess is not). The view also gained `counts?.` so a future shape change can
never blank it again.

## Verified

```
bun test  · 9/9 (server/kaia.test.ts — the resolver and the adapter)
  YMIR_PI_BIN wins for a real executable · a stale override loses to PATH
  the command keeps argv intact · health gains ok/db · inspect gains db/counts
  counts are never invented · an existing counts object is preserved
  recall/timeline pass through · a non-object payload is unchanged
vue-tsc --noEmit  · clean
```

**Live, under the service's own restricted PATH** (`PATH=/home/heimdall/.bun/bin:/usr/bin:/bin`),
a second instance on `:8438` answered both:

```
GET  /api/memory/inspect → db: …/kaia.engram · counts: {episodes:133, facts:36, entities:60, edges:480}
POST /api/chat/message   → {"role":"kaia","content":"OK"}     (was: 500 Executable not found)
```

## Not changed

`dist/` was **not** rebuilt into the commit: the hashed bundles it replaces are tracked files, and
replacing them is a deletion the no-delete guard refuses. The fix is server-side and works with the
existing bundle (the view change only hardens it), so the next ordinary build picks it up.
