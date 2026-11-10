# The spawn names the tree where the pins live, not the one it just emptied

**2026-11-10 · component: runtime · `src/ymir_runtime/seat.py`**

A seat launch that removes a thing and then demands it is a launch that never happens. It
happened here, and the message it left was the clue it was not believed:

```
holds no .pi/extensions tree
```

## What it did

`seat()` built the launch command with `launch_cwd=tree.path` — the **worktree**. That argument
does not choose where the agent runs (`cd` does, and the launch script owns it); it chooses
which extension set the harness is told about. But the same spawn had already deleted the
worktree's `.pi/extensions`, on purpose, so pi would not load one tool twice (the one-home
change, RULES/13). So the door removed the tree it then pointed at, and every pi dispatch
refused.

## What it does now

```python
launch_cmd = harness.build_launch_command(selection, str(prompt_path), launch_cwd=roots.root, runner=runner)
```

The pins are named from the **project tree**, where they actually live, while `cd` still goes
to the worktree so the work happens in isolation — which is the whole point of the worktree.
Two facts were being carried by one argument; they are now separated, and the comment says
which is which so the next hand does not re-merge them.

**Measured 2026-11-09**, in the words of the line that was failing: a door that removed what it
then demanded refused every pi dispatch.

## What this note does not claim

It does not claim the worktree is unused, or that `launch_cwd` means "where the agent runs".
Both readings caused this fault once already.

## CHANGE LOG

- **2026-11-10** — written. The change it records was found uncommitted on `main` during a
  housekeeping pass; it is carried here on a branch, never merged by an agent.
