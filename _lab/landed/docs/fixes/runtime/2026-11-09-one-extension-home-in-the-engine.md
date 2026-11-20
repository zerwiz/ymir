## runtime · 2026-11-09 — one extension home, and the engine finally keeps it

### The fault

Three errands died tonight in the same way, and the message was identical each time:

```
Error: Failed to load extension "~/ymir/.pi/extensions/elder.ts":
  Tool "ymir_push" conflicts with .../.yggdrasil/<id>/.pi/extensions/elder.ts
```

pi walks up from the worktree, finds the project's extension tree **and** the worktree's copy, loads every tool twice and
refuses to start. The seat then never stands — and a seat that never stands still reads `working` to a sweep, which is how
`connect-door`, `connect-door-2` and `sessrumnir-narrow-review` all looked alive while they were not.

### Why only the engine's road was affected

`bin/agents/einherjar-spawn.sh` has carried the fix since it was written: after creating a worktree it removes
`<wt>/.pi/extensions` and marks the path `assume-unchanged`, so the deletion never rides in the worker's commit.

`src/ymir_runtime/worktree.py` — the **engine's** road, which takes over as soon as a seat record exists — did not. Two roads,
one rule, and the newer road was the one without it. That is RULES/13's exact warning: *two load paths seats nobody*.

### The fix

`worktree.ensure()` now drops the worktree's `.pi/extensions` immediately after creation and marks it `assume-unchanged`, in
the same shape as the spawn script, with the reason written where the code is. The project's own tree is untouched.

### Verified

```
$ cd src && python3 -m unittest ymir_runtime.tests.test_worktree
Ran 6 tests — OK
```

The new test builds a repo that **has** a committed `.pi/extensions` tree, creates a worktree through the engine, and asserts
both halves: the worktree carries no second tree, and the project's own tree still holds its file.

## CHANGE LOG

- **2026-11-09** — Carved: the engine's worktree road drops the duplicate extension tree, with a test that fails without it.
