## harness-integration · unversioned · 2026-10-04 — the extension tree mirrors its source

### Why

Rule 13 §3 says a multi-file extension is a **directory with an `index.ts`**, and an
extension's own internals live inside it. **The tree did that in no places**, and the
reason was measurable rather than stylistic: **`lib/` was imported by extensions that
had no relationship to the modules.**

| module | importers | consequence |
|---|---|---|
| `ymir-home` | 5 | genuinely shared — belongs in `lib/` |
| `rodd-operational-input` | 3 | genuinely shared |
| **`ro-visibility`** | **3** (ro, gna-pi-watch, skuld) | **not Ró's private helper** — that is why a shared `lib/` existed at all |
| `skuld-branch-dispatch` | 2 | shared |
| `ro-assistant-layout` · `ro-operational-user-layout` · `ro-working-ship` | 1 each | **ro-private — moved** |
| `skuld-branch-model-picker` | 1 | **skuld-private — moved** |
| `constellation-registry` · `constellation-contract` | 1 | **constellation-private — moved** |

**Five modules had exactly one owner and were living in a folder shared by five
different extensions.** That is why the source was split across two trees.

### Fix

- **`.pi/shared/extensions/` is now ONE tree.** `lib/` moved out of the old flat
  `.pi/extensions/` and in beside the extensions that import it. The second source
  directory is gone.
- **Three extensions became directories:** `ro/index.ts`, `constellation/index.ts`,
  `skuld-branch-supervision/index.ts`, each with its own modules beside it.
  Imports followed ownership — `./visibility` for its own, `../lib/` for shared.
- **`lib/` is now five modules, each with a stated reason**, and `lib/` has no
  `index.ts` so pi never scans it as an extension.
- **Tests travel with their owner** (`constellation/*.test.ts`) and never deploy.
- **The deploy mirrors the tree.** A recursive `deploy_ext_tree` replaces two
  hand-written copy loops, so a subdirectory reaches the deployed home intact.
- **The deploy PRUNES.** A deploy only ever adds, so a restructure leaves the old
  file beside the new directory — `ro.ts` and `ro/index.ts` both load, both register
  Ró's tools, and pi exits with a tool-name conflict so **no agent can be seated**.

### Verified with pi's own loader, not an assertion

The installed `discoverAndLoadExtensions` was run against a **test home** and then
against the live tree:

```
DISCOVERED: 19     ERRORS: none
   …/extensions/constellation/index.ts
   …/extensions/ro/index.ts
   …/extensions/skuld-branch-supervision/index.ts
```

`lib/` is not discovered (no `index.ts`) and no test file is deployed — both correct.
All 22 relative imports resolve in the source tree.

### Two mistakes this change actually made, and what caught them

**1. A `sed` corrupted two extensions.** `'s|"\.\./lib/|""./lib/|'` inserted a literal
`""` into 49 import lines across `gna-pi-watch.ts` and `syn-turnend-guard.ts`. The
first sign was pi's own loader: `ParseError: Missing semicolon … gna-pi-watch.ts:50:9`.
**Two files the restructure depended on could not parse.** Fixed and re-verified.

**2. The prune wiped the live extension tree — 43 files.** The first version removed
everything not named `.ymir-root`, instead of comparing against the source at the
same relative path. **`.ymir-root` went with it**, so every deployed extension lost
its `bin/` resolution. Caught immediately by listing the tree, fixed to compare
paths, and the tree rebuilt from source in the next run.

**Both were caught by checking the artefact rather than the exit code** — a rule this
repo has now written down several times, and the first time it caught me inside the
change that was supposed to be enforcing it.

### A live mistake worth naming

Midway through, the restructure was deployed from the **worktree** rather than from
main. `.ymir-root` then listed the worktree first, so the live harness's extensions
would have resolved `bin/` — and `state/` — to a checkout that is not the session's.
**The live tree was put back on committed code** and the three new directories
removed by hand, because the main loader has no prune. `DISCOVERED: 19, ERRORS: none`
afterwards.

### Not done

**The nine no-op stubs are still in `.pi/extensions/`.** They register nothing, so
they are not a collision, and deleting them is a separate decision — it changes what
pi discovers at seat time. Rule 13 §2 forbids them growing, not existing.

### A note on where fix notes for this surface go

These notes were first filed under `docs/fixes/harness-integration/`, mirroring the
asset that governs the surface. **The fixes gate cannot see them there** —
`bin/fixes-guard.sh` matches notes with `^docs/fixes/[a-z]+/…`, and a hyphen in a
component name is invisible to it, so the push was refused with *"no fix note in
this range"* while three correct notes sat in the range.

**The gate's own map answers the question anyway:** `.pi/*` → **`agents`** and
`bin/valknut-load.sh` → **`install`**. So the notes moved to the two components the
gate already knows, rather than the gate being taught a new one.

**Worth noting that the two governing documents disagree.** `AGENTS.md` sends
`.pi/**` work to the **harness-integration** asset, while `bin/fixes-guard.sh` calls
that same work **`agents`**. The asset name and the component name are not the same
vocabulary, and a reader who trusted the first would file a note the second cannot
read. Recorded rather than fixed here: aligning them is a change to the guard's map
or to `AGENTS.md`, and neither belongs in a restructure.
