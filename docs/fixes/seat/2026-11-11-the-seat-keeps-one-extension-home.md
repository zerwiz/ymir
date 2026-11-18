## seat · 2026-11-11 — one extension home for the seat started by hand

### The fault

`pi`, typed in `~/ymir`, printed forty-four lines of

```
Error: Failed to load extension "~/ymir-runtime/.pi/extensions/constellation/index.ts":
  Tool "constellation_list" conflicts with ~/ymir/.pi/extensions/constellation/index.ts
```

and loaded none of them. Measured the same minute:

```
$ cd ~/ymir && pi --list-models | grep -c 'conflicts with'        # 44
$ cd ~/ymir/.yggdrasil/<worktree> && pi --list-models | ...       #  0
$ cd ~/ymir-runtime && pi --list-models | ...                     #  0
```

Pi's own loader (`dist/core/extensions/loader.js:667`) takes
`<cwd>/.pi/extensions`, then `~/.pi/agent/extensions`, then every directory named in the
settings `extensions[]` — and de-duplicates on `path.resolve(p)` **alone**. This machine
has two full checkouts of the same repository: the working tree `~/ymir` and the pinned
runtime `~/ymir-runtime` (`$YMIR_HOME/config/runtime.env`). The settings name the runtime;
a session started at `~/ymir` also discovers the working tree. Two paths, two homes, every
tool twice, and Pi refuses every extension (RULES/13).

A **dispatched** worker never met this: `bin/agents/einherjar-spawn.sh` hands each pane the
shape from `bin/seat/pi-launcher.sh` — `-ne` plus one `-e` per pin, resolved from the
worktree — and the worktree itself is sparse-excluded. The seat the Allfather starts by hand
had no such door, so the one road with no door was the only road that broke.

### The fix

`bin/seat/pi-door.sh` — the same shape, for a hand-started seat, and one decision per
launch:

- the caller already names its extensions (`-ne` / `-e`) → handed through untouched;
- `<cwd>/.pi/extensions` absent → handed through untouched;
- the settings name that same directory → handed through untouched (Pi de-duplicates it);
- the settings name **another** checkout → discovery off (`-ne`), the cwd's own tree named
  once from its own path, and the seat's npm `packages` carried explicitly.

`bin/seat/harness-extensions-install.sh` seats it as `~/.pi/agent/bin/pi` (first on `PATH`)
on install and on every update, and reports the copy `stale` when the door has moved — a
copy, never a symlink, because a symlink into a checkout dies with the branch.
`bin/seat/valknut-load.sh --check` accepts a settings entry that names another tree **only**
while that door is seated, since the door is what reconciles the launch.

### Verified

```
$ bash bin/seat/tests/test_pi_door.sh
7 passed, 0 failed

$ cd ~/ymir && bin/seat/pi-door.sh --why
pi-door[1]{verdict,tree,reason}:
  "onehome","/home/zerwizomar/ymir/.pi/extensions","the settings also name /home/zerwizomar/ymir-runtime/.pi/extensions"

$ cd ~/ymir && PI_DOOR_VERBOSE=1 pi-door.sh --list-models 2>&1 | grep -c 'conflicts with'
0
$ cd ~/ymir/.yggdrasil/<sparse worktree> && pi-door.sh --list-models 2>&1 | grep -c 'conflicts with'
0
```

The test drives a fake harness and asserts the argv: `-ne` first, the flat pin and the
directory pin named once each, `README.md` and `lib/` never named, the seat's package
carried, a caller-led argv untouched, a same-tree settings entry untouched, and a missing
harness refused in words.

## CHANGE LOG

- **2026-11-11** — Carved: the hand-started seat gets the one-home door the dispatched worker
  always had, installed as `~/.pi/agent/bin/pi`; the extension-home check accepts the
  reconciliation it performs.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: the heart's user. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
