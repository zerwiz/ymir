## seat · 2026-11-11 — every root agent loads the pinned runtime; pi's root carries Ymir's set (plan 248 P2 + P3)

### The fault

The fix note written earlier today (`2026-11-11-the-seat-keeps-one-extension-home.md`) recorded that *"the settings
name the runtime"*. By the evening they no longer did. Measured on the first seat:

```
~/.pi/agent/settings.json  extensions[]  → /home/<user>/ymir/.pi/extensions        (the WORKING TREE)
$YMIR_HOME/config/runtime.env            → YMIR_RUNTIME_DIR="$HOME/ymir-runtime"   (the pin)
```

`bin/seat/valknut-load.sh` read `runtime.env` with
`sed -n 's/^YMIR_RUNTIME_DIR="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p'`. That keeps `$HOME/ymir-runtime` as literal text, a
directory that never exists. So the pin was ignored without a word, and `PI_EXT_SRC` fell back to the checkout the
script ran from. Each `valknut-load --global` run from `~/ymir` then took out the runtime's entry, because
`is_other_ymir_extensions` drops the entry for any other checkout, and put the working tree in its place. From
then on a `git checkout` in `~/ymir` changed the code every pi root agent loaded. That is the root of the PR #654
duplicate-tools class.

The same scan found the working tree in the ymir MCP door in pi (`mcp-adapter.json`, `mcp.json`), in Claude Code
(user-scope `~/.claude.json`), in OpenCode and in Cursor, and in the `.ymir-root` record. It also found a
Yggdrasil worktree path (an hnoss errand) in five roots. `bin/bridge/mcp-config-seat.py`'s `stable_root()` already
preferred `YMIR_RUNTIME_DIR`, but nothing exported that variable to it.

The pi packages were named in two places that had drifted apart. `bin/pi/pi-ensure.sh` required `pi-mcp-adapter`,
`pi-web-access` and `pi-lmstudio`. The settings also carried telegram and ask-user, which no installer knew about.

### The fix

- **One reader:** `bin/seat/runtime-root.sh`. It **sources** `runtime.env` in a subshell, as `runtime-deploy.sh`
  always has, so `$HOME` is expanded. It sets `YMIR_RUNTIME_ROOT`, `YMIR_RUNTIME_SOURCE` (`pinned` or `checkout`)
  and `YMIR_RUNTIME_REASON`. A fallback to the checkout is always stated. It refuses a pin that is not a Ymir
  checkout. `valknut-load.sh`, `harness-extensions-install.sh`, `pi-ensure.sh` and `mcp-config.sh` all read the
  runtime through it.
- **One ward:** `bin/seat/runtime-roots.py`, run as `runtime-root.sh scan|repoint`. It reads every harness root
  config Ymir writes and finds each path that lands in a Ymir checkout other than the runtime. A checkout is
  recognised by its marks: `RULES/` beside `bin/seat/valknut-load.sh`. That catches a fork, a second clone and a
  worktree without keeping a list of names. `repoint` swaps each such path for the runtime's copy of the same
  file and keeps one backup. A path with no copy in the runtime is **held**: it is named and never guessed at. In
  `~/.claude.json`, only the user-scope `mcpServers` is touched.
- **The checks refuse it.** `valknut-load.sh --check` has a `pi's root names a working tree … FAIL` row, followed
  by a `remedy` row. `harness-extensions-install.sh --check` reports a `roots,stale` row for each working-tree
  path and exits 1.
- **Install re-points it.** `harness-extensions-install.sh` passes `PI_EXT_SRC` explicitly, because a runtime
  deployed before this change still carries the old sed reader. It installs the pi root set, then runs `repoint`
  over every root last.
- **The `.ymir-root` record** puts the pinned runtime first and drops other checkouts. The deployed extensions
  resolve `bin/` from the runtime, the same tree they were loaded from.
- **The pi root set, in one place.** `.agents/harnesses/pi.yaml` now carries `root_extensions` (`ro`, `todo`,
  `open-editor`) and `packages` (`npm:pi-mcp-adapter`, `npm:pi-web-access`, `npm:@llblab/pi-telegram`,
  `npm:@juicesharp/rpiv-ask-user-question`). `pi-ensure.sh` reads that list, refuses to guess when it cannot read
  it, and proves each root extension stands in the runtime's tree and that the root settings name that tree.
  `pi-lmstudio` is no longer on the list, because LM Studio was retired on 2026-10-24. A seat that has it keeps it,
  since the installer never removes a package.
- **Carried everywhere.** The installer and Gróa's update already pass through `harness-extensions-install.sh`.
  Eir gains a `roots` surface: a check names the count, and the fix is the same door. Migration
  `0022-roots-load-the-runtime` heals a home installed earlier. 0022 is the next free number on `origin/main`,
  where 0012 and 0018 are already used twice.
- **The one-home door is unchanged.** `bin/seat/pi-door.sh` still gives a session started inside a checkout that
  checkout's own tree, once, while the root names the runtime. The ward's case 5 proves it.
- **Every platform layer (RULES/05).** The change is in the portable core: bash, `python3` and `awk`, with no GNU
  `readlink`. The Omarchy, macOS and WSL installs all reach it through the same `ymir-install.sh` → `loaders` →
  `harness-extensions-install.sh` road. No layer keeps its own copy.

### Proof

`bin/seat/tests/test_roots_load_the_runtime.sh` runs 8 of 8 in a throwaway HOME. It uses two real clones (the
runtime and a working tree), a fake `pi` on a bare PATH, and `runtime.env` written with a literal `$HOME`. It
proves the pin, both refusals, the install, a session in `~` and one in an unrelated project, the door's one-home
rule inside the working tree, an update (a re-run plus migration 0022 that writes no new backup), and the unpinned
fallback.

The real `pi` 1.5.2 was also run in a throwaway HOME whose root names a runtime clone. `pi -p` loaded Ymir's
extensions, and the constellation and excalidraw extensions spoke, from `~` and from an unrelated project, with
zero conflicts. The real `~/.pi`, `~/.claude`, `~/.config/opencode` and `~/.agents` were read only, with
`repoint --dry-run`, and never written.

### Not done here

The live seat's own roots are not re-pointed. That happens on its next update, or now with
`bin/seat/harness-extensions-install.sh`. The hnoss errand path will be **held** until that errand lands or is
dropped. P3b (the one `ymir` skill), P4 (every harness's full root set) and P5 (the contract in the root) are the
next phases of plan 248.

## CHANGE LOG

- **2026-11-11** — written with the fix (plan 248 P2 + P3, errand roots-load-the-runtime).
