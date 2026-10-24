# `exec` cannot take an assignment — every opencode seat was born dead

**2026-10-24.** Component: `bin/agents/einherjar-spawn.sh`, `build_launch_command`.

## What

The opencode branch built this line into `state/<id>.launch.sh`:

```
exec OPENCODE_CONFIG_CONTENT='{"permission":{"*":"allow"}}' opencode --model … --prompt "$(cat …)"
```

`exec` takes a **command**, not a variable assignment. bash therefore reported

```
state/gate-outbound.launch.sh: line 4: exec: OPENCODE_CONFIG_CONTENT={"permission":{"*":"allow"}}: not found
```

and exited within a second. The pane fell back to a shell; the dispatcher printed `spawned … backend=herdr`
and wrote a heartbeat baseline. Four errands were dispatched this way and four empty panes sat there,
including the one that was supposed to build plan 128.

## Why it hid for so long

The launcher redirects the pane's output and reports on **the launch call**, not on the harness. A seat that
dies one line later is indistinguishable from a seat that started. That is the same family as the extension
collision of the same morning: *"started" taken for "seated"*.

## The fix

`env` carries the assignment through the exec:

```
exec env OPENCODE_CONFIG_CONTENT='{"permission":{"*":"allow"}}' opencode --model … --prompt "$(cat …)"
```

## How to see a seat that is actually alive

```bash
# the door's own record
tail -3 state/<id>.status
# the harness, in the worktree, right now
pgrep -af "opencode|pi --model" | grep .yggdrasil/<id>
# or, by panel
herdr agent list
```

## Owed (named, not hidden)

- **The launcher must verify the seat**, not the launch: after typing the command, wait for the harness
  process in the worktree and fail loudly (exit non-zero, print the pane tail) when it never appears. Two
  dispatches were lost today to this absence.
- **The pi branch needs the same eye**: a pi seat in a worktree collides on `.pi/extensions` (see
  `2026-10-24-the-errand-that-looked-alive.md`); the durable fix is the sparse-checkout exclusion in
  `bin/forge/yggdrasil.sh`, and until it lands the worktree's own tree is the only one that may load.
