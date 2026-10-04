## harness-integration · unversioned · 2026-10-04 — the extension tree gets a gate, and the tests stop shipping

### Why

- **The running harness was on stale code and nothing said so.** A deploy is a
  *copy* — `bin/seat/valknut-load.sh --pi` copies `.pi/shared/extensions/` into
  `~/.pi/agent/extensions/` and nothing re-runs it — so a repo edit does nothing
  until someone remembers. Measured: the deployed `ymir-subagents.ts` was **12,991
  bytes against a 13,748-byte source**, and the ten missing lines are
  `bin/agents/erindi-brief.sh`. Their own comment: *"the seat door REFUSES an unfilled
  brief… A dispatch that produced a placeholder brief would **seat a figure with
  nothing to do**."* Every file listing looked correct.
- **Two test files were being deployed into the live tree on every loader run.**
  `constellation-load.test.ts` and `constellation-registry.test.ts` live in
  `.pi/extensions/lib/`, and the copy loop took everything in that directory.
  They are harmless to the loader — a `.test.ts` is not a discoverable entry point,
  because pi requires a direct `.ts`/`.js` file or a subdirectory with `index.ts` —
  but they were being read as part of the shipped extension set.
- **Nothing could catch either.** `--status` reports bindings; it never asks whether
  the deployed bytes match the source.

### Fix

- **`bin/seat/valknut-load.sh` no longer copies `*.test.*` / `*.spec.*` into the live
  tree**, and removes any that an earlier run already deployed — otherwise the
  exclusion would not actually take effect.
- **`bin/seat/valknut-load.sh --check` is a new gate** with five checks and exit 1 on
  failure, so it can sit in CI or a hook rather than in someone's memory:
  1. every deployed extension is byte-identical to its source
  2. every helper module the shared set imports is deployed too — deploying the
     top-level files *alone* ships extensions that cannot load
  3. no test file is in the live tree
  4. **no extension exists in two load paths** — the collision that makes pi exit
     with a tool-name conflict, so no agent can be seated
  5. the count of project-local no-op stubs is reported, so deleting that tree
     later is a decision rather than a surprise
- **`PI_EXT_LIB_SRC` is now named once**, at the top with the other paths, so the
  gate can see the helper tree without running a deploy.

### The gate was itself wrong first, and fault injection found it

A gate that only ever passes is worse than no gate, so each check was proved by
breaking the thing it watches:

| injected fault | caught |
|---|---|
| `ro.ts` deployed stale | ✅ `STALE — deployed differs from source`, exit 1 |
| a test file in the live tree | ✅ `LEAKED`, exit 1 |
| an extension in source but not deployed | ✅ `NOT DEPLOYED`, exit 1 |
| a helper module removed from the live tree | ✅ `NOT DEPLOYED`, exit 1 |
| a project-local file copied verbatim from source | ✅ after a fix — see below |

**The fourth check was wrong on its first run.** It skipped any project-local file
byte-identical to the source, reasoning that only a *different* file could collide.
**A file copied verbatim collides just as hard** — it registers the same tools from
a second directory pi already scanned. The rule is now the plain one: a
project-local extension file must either not exist, or register nothing.

### Also found, and NOT changed here

- **`.ymir-root` lists two dead Yggdrasil worktrees.** Reported as a defect and
  then withdrawn: `lib/ymir-home.ts` already validates every recorded root against
  `bin/syn-watch-arm.sh` and skips any that no longer exists, and the multi-line
  record is by design (*"one absolute root per line, most recent first"*). It is
  hygiene, not a bug, and it is left alone.
- **The layout fault is not fixed here.** `lib/` is still sourced from the old flat
  tree while the extensions come from `.pi/shared/extensions/` — plan 29 built them
  there and the single-home migration moved the extensions but not their internals.
  `PI_EXT_LIB_SRC` now carries a comment saying so, and the move is separate work
  on `.pi/shared/extensions/`. Full analysis, including why the "thin loaders" in
  plan 58 can never be built:
  `~/Documents/ymirhome/hodd/docs/developer-setup/2026-10-01-pi-extension-system-layout.md`.

### Verified

```
$ bash bin/seat/valknut-load.sh --check
  all extensions byte-identical to source        PASS
  all helper modules byte-identical              PASS
  no test files in the deployed tree             PASS
  no extension in two load paths                 PASS
  project-local no-op stubs                      9 present (each must register nothing)
  valknut-load --check                           PASS        exit 0
```

**18 relative imports in the deployed tree resolve, 0 unresolved.** The gate is
exercised from an isolated worktree, not the main tree.
