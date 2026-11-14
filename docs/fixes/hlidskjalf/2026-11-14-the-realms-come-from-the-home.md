# hlidskjalf · 2026-11-14 — the realms come from the home, never from the code

**Component:** hlidskjalf · **Branch:** `eindri/hall-realms-from-home` (lands `eindri/hall-follow` and
`eindri/leak-health-view`)
**Files:** `apps/hlidskjalf/src/data/realms.ts`, `src/services/auth.ts`, `src/state/store.ts`,
`src/hooks/useTenantDef.ts`, `src/components/RealmScope.tsx`, `server/realms-registry.test.ts` (new),
`server/index.ts` (one comment), `AGENTS.md`, `docs/features/hlidskjalf-the-control-plane.md`,
`.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md`, `bin/gates/ci-verify.sh`

## Why

Two branches of Hlidskjalf work — one Hlidskjalf with no modes and one door to Skírnir, every
realm shown with Skrymir on the whole home, and the Health view — were refused by the gather for
one reason: a **person's own name was written in the code as a third realm**. `WORKSPACES` in
`src/data/realms.ts` and `baseGrants()` in `src/services/auth.ts` both carried it, and the NDA and
public-data wards refused the push, correctly. The work was finished; it simply could not travel.

The realm list is private data (RULES/04). It belongs to the operator's own home, in
`hodd/identity/workspaces.yaml`, and the gate has read that file at `/api/workspaces` since the
workspace registry landed. The page never asked it.

## What changed

**The shipped build carries a generic pair.** `DEFAULT_WORKSPACES` is `work` and `personal` with
their house tints and runes. Nothing else ships: no realm's name, no company, no machine.

**The gate's answer is the realm list.** `realmsFromRegistry()` turns the rows the registry
answers with into what the UI draws. A realm the build already knows keeps its own colour and
rune; one it does not know takes a **stable seal** derived from its own id, so it looks the same
on every machine without a line being written down.

**The seat holds the list.** `store.realms` starts as the shipped pair and `loadRealms()` fills it
from `/api/workspaces` — at boot, at `establishSession`, and whenever a page asks again. If the
seat's realm is not in the list the scope moves to the first one that is, and the session's
tenants are re-derived from the same list, so Profile, the Forge filter and the OmniChat drawer
all show the same realms. `sessionFor`, `baseGrants` and `provisionWorkspace` take the list as an
argument; they no longer know any realm by name.

**A registry that cannot be read is not an empty home.** Every failure path — no home, no
registry, an empty one, a bad one — answers the shipped pair, and the page still opens.

**Two names left the shipped text.** Three lines in the merged work quoted the third realm by
name (a comment in `server/index.ts`, two fix notes, `AGENTS.md`). They now say "the other
realms" and "a third realm". A name in a public file is a name in a public file, even inside a
note explaining why it should not be there.

## How it was proved

**The unit test** — `apps/hlidskjalf/server/realms-registry.test.ts`, written on `node:test` so
CI's pinned Node runs it, registered as the gate `realms-from-registry` in `bin/gates/ci-verify.sh`:

```
node --test apps/hlidskjalf/server/realms-registry.test.ts   ✔ 11 pass, 0 fail
bun test server/realms-registry.test.ts                      ✔ 11 pass, 0 fail
```

What it holds: the shipped list is exactly two generic realms and no registry realm's name
appears in `realms.ts` (the fence that would have caught the original leak); every registry row
lands in order under the registry's own name; an unknown realm's seal is stable across a rename and
follows its id; the two known realms keep their own colour and rune; duplicate and blank rows are
dropped; empty, null and missing registries all answer the pair; the session carries one tenant
per realm and never fewer.

**The shell and the build** — `npx tsc -p apps/hlidskjalf/tsconfig.json --noEmit` clean;
`npx vite build` clean (348 modules, `dist/assets/index-CwH5Wxiu.js`).

**A real browser, against both homes** — a built `dist` served on `:3988`, the gate from this
worktree on `:3987`, and Chromium through the DevTools protocol (`--remote-debugging-port`),
driven by Playwright:

```
real home (the operator's registry)
  #/forge     realm filter = three chips, all from the registry: Work · Personal · <the third's
              own name>; the third wears a seal derived from its id, not a house colour
              click the second → aria-pressed moves, document data-realm = personal
  #/chat      drawer closed by default; open → the same three chips; click the third →
              pressed moves, data-realm = <the third>
  #/profile   one row per realm, each with its shelf svartalfaheim/<realm>
  #/runtime   Health — every service and app, measured · last pass 12 h 14 min ago · 15 passes ·
              "The ledger has not moved …" · Services, Apps — their last soak, Stopped by the
              restart ward; the budgets behind one fold
  #/skirnir   Skírnir – Tala · Rödd — the live voice · Talk with Skírnir · the listen control
  console     no page errors; no 4xx/5xx except /api/stream (below)

an empty home (a temp directory, no registry)
  GET /api/workspaces  → the generic pair only
  #/forge              → two chips: Work · Personal
  #/profile            → two rows, and nothing else
```

`/api/stream` answers 500 under `vite preview`; it is the live SSE proxy, untouched by this
change and not on any screen this errand opened.

## What this does not do

- **It does not add a second source of realms.** The registry is the one the house already reads;
  the realm folders under `svartalfaheim/` are shown by Skrymir (the whole home) and are not
  turned into filter chips, because a company realm is not a workspace.
- **It does not touch the sampler.** The Health view reads the leak ledger as it lands; the timer
  on this machine is stopped and the page says so.
- **The Health view's own test** (`server/health.test.ts`, 20 assertions) is written on
  `bun:test`, so CI's Node cannot run it; it was run with `bun test` here and is not registered as
  a gate. Making it a `node:test` file is owed by that view's own line of work.

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #763
