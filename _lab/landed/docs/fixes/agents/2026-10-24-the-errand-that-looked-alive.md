# The errand that looked alive — a seat that reported success with no mind in it

**2026-10-24.** Component: `bin/seat/herdr-run.sh` (the seat road), `src/ymir_runtime/seat.py` (the engine's
door to it).

## What happened

Three dispatches of one errand (`clients-128`) reported `spawned`, opened a pane, wrote a "working" status
line — and left a bare shell at a prompt. Nothing ran. One of them was a pi seat that died **2.4 seconds**
after starting (herdr's own log: `agent changed … agent=Some(Pi)` at `08:02:50.989`, then `agent=None` at
`08:02:53.399`).

The pane's own output said why:

```
Error: Failed to load extension "~/ymir/.pi/extensions/ymirhome.ts": Tool "ymir_place" conflicts with
       ~/ymir/.yggdrasil/clients-128/.pi/extensions/ymirhome.ts
… eighteen of these …
Hint: Start without extensions using "pi -ne".
```

## The fault

A Yggdrasil worktree carries its own `.pi/extensions` (a full copy of the repo), **and** the seat's user
settings name the primary checkout's `.pi/extensions`. pi loads both, every tool name collides, pi refuses
**all** extensions, exits, and the pane falls back to a shell — which the dispatcher then types the brief
into. A shell accepts text happily.

Two faults, and the second is the worse one:

1. **Two load paths for one extension.** `RULES/13` forbids exactly this, and nothing enforced it inside a
   worktree.
2. **"Started" was taken as "seated".** Nothing checked that an agent had registered, so a dead seat was
   indistinguishable from a working one. This is the family of fault the house has been finding all week: a
   door that says yes and does nothing.

## The fix (this change)

- **One extension home per pi seat.** When the seat's working directory is not the seat root, `herdr-run.sh`
  starts pi with discovery **off** and exactly one explicit tree:
  `pi -ne -e <seat-root>/.pi/extensions`. Verified by hand inside the failing worktree:
  `pi -ne -e /home/heimdall/ymir/.pi/extensions --list-models` exits 0 and lists the rail — the same command
  that produced eighteen collisions before.
- **Registration is the proof.** After `hdr agent start`, the road now waits for `hdr agent get <name>` (up to
  10 s). If the agent never registers, it **fails loudly**, prints the pane's tail with its reason, and exits
  non-zero — instead of printing `spawned`.

## What is still owed — named, not hidden

- **A second launch path with a dead door.** `src/ymir_runtime/seat.py:68` resolves the seat road as
  `bin/herdr-run.sh`; that file no longer exists (it lives at `bin/seat/herdr-run.sh`). So the engine's handoff
  is stale and every dispatch falls back to the old road. One spawn path is the law; there are still two, and
  one of them points at nothing.
- **A close that leaves a worker behind.** `einherjar-spawn.sh --relaunch` after a `close` left a process
  waiting on `state/local-model.lock` alive; it had to be killed by hand. A close must take the process group.
- **A wake that names the errand, not the run.** The queue woke Brokk for a dead attempt's report as if it
  were news.

## How to see it

```bash
# the fault, reproduced by hand inside any worktree
cd .yggdrasil/<errand> && pi --list-models        # eighteen collisions, exit
# the fix, proved
cd .yggdrasil/<errand> && pi -ne -e "$(cat ~/.pi/agent/extensions/.ymir-root)/.pi/extensions" --list-models
```

---

## Correction and the actual root (same day, after the Allfather's rebuke)

He said it plainly: *"we have scripts and extensions for this."* He was right, and the hand-patched
`-ne -e` experiment in `einherjar-spawn.sh` and `herdr-run.sh` was backed out undelivered — the house door
for this is `bin/seat/valknut-load.sh` (its own header states the law: pi loads BOTH the project tree and the
settings-named tree and does not de-duplicate).

**The real duplicate is the WORKTREE's own copy.** A Yggdrasil worktree checks out `.pi/extensions/` like any
other file, so a seat inside it has two trees carrying the same eighteen extensions — the checkout's and the
worktree's — regardless of what the settings say. Removing that second copy makes the plain house road work:
with `<worktree>/.pi/extensions` pointing at the seat root's one tree, `state/<id>.launch.sh` (plain `pi
--model …`, no flags) starts and **stays up** — measured at 2 min 45 s and climbing, on branch
`eindri/clients-128`, the first live seat of the day.

**So the durable fix belongs in `bin/forge/yggdrasil.sh`**, not in the spawn road: a worktree must not carry a
second `.pi/extensions`. The clean way is a sparse-checkout exclusion of that path when the worktree is
created (a symlink works and was used to prove the diagnosis, but it shows up as deleted tracked files and
must not be the shipped answer). And `valknut-load.sh --check` should gain the worktree case: *the tree in
this worktree is the same home as the seat root's, so it is not a second home.*

**Also fixed here:** `src/ymir_runtime/seat.py` resolved its `worth-a-smith` door as `bin/herdr-run.sh`, which
moved to `bin/seat/herdr-run.sh` in the restructure; the engine therefore answered "no worth-a-smith door on
this machine" and dispatched on the brief alone, silently, for every errand. It now resolves the current path
and keeps the old one as a fallback.
