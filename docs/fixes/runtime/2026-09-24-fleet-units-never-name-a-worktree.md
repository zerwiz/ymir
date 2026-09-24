## runtime · 2026-09-24 — the fleet's permanent units must never name a worktree

### Why
A smith ran `bin/fleet-ensure.sh ensure` **from its Yggdrasil worktree**. The seat's
durable systemd units came out pointing at that disposable tree:

```
~/.config/systemd/user/nornir.service
  ExecStart=/bin/bash /home/heimdall/ymir/.yggdrasil/ymir-autoboot/bin/nornir-cron-start.sh
```

Two consequences, both bad:
- **A silent boot failure waiting.** Pruning the worktree leaves the unit execing a path
  that no longer exists. The seat's cron would die at boot with nothing said.
- **A confused proof.** The live scheduler carries the worktree's identity, so
  `autoboot_cron_up` answered `no` and `bin/ymir-autoboot.sh verify` reported the seat
  FAIL for `nornir` — a false negative, because the loop it was hunting was the wrong
  tree's.

The file already had the right idea in `FLEET_TEMPLATE_ROOT` ("the tree that SHIPS the
templates may differ from the seat's platform root") — but the default WAS the caller's
tree, so any run from a worktree wrote the worktree's path into the operator's permanent
units. This is the same defect `bin/eindri-watch.sh` fixed for its watcher specs
("Resolve to the MAIN tree via git's common dir, so an arm from any worktree records the
same adapter").

### What
- `bin/fleet-ensure.sh` — when no explicit `FLEET_TEMPLATE_ROOT` is given, resolve it to
  the **MAIN tree** through `git rev-parse --git-common-dir` (in the main tree it resolves
  to itself, so it stays idempotent). An explicit override still wins, which is the
  documented way a changed tree raises an existing seat.
- A new guard, `refuse_disposable_path <unit-file>`, called after EVERY unit write
  (embed, the web stack, the target, and every mill/office template): a unit that names a
  `.yggdrasil/` path is **refused loudly** with the remedy, never seated. A disposable path
  in a durable unit is a boot failure waiting to happen, so it fails at the write.

### Verified
- The resolution, run from a real worktree:
  `ROOT=.yggdrasil/ymir-autoboot` → resolved durable root `/home/heimdall/ymir`. Correct.
- The guard, exercised both ways: a unit naming `.yggdrasil/foo/bin/x.sh` → rc=1 (refused);
  a unit naming `/home/heimdall/ymir/bin/nornir-cron-start.sh` → rc=0.
- `bash -n` clean.

### Files
- `bin/fleet-ensure.sh`
