# The installer names a worktree-seated unit as fragile

**Date:** 2026-10-23 · **Component:** mail (Gná) · **Follows:** `2026-10-23-the-desk-stands-alone.md`

## The fault this prevents

To make the desk production-ready tonight, `gna-desk.service` had to be seated from
`feat/mail-gate`'s worktree — main carries no `bin/mail/` until the branch merges. A unit whose
`ExecStart` points into `.yggdrasil/` **dies the day that worktree is pruned**, and it would die at a
reboot, which is the worst moment to discover it.

## The change

`bin/mail/install.sh` now checks whether `$ROOT` sits under `/.yggdrasil/` and, if so, prints a WARNING
on stderr naming the worktree and the one command that re-seats it:

```
install: WARNING — seated from a worktree (/…/.yggdrasil/mail-gate), not from the main tree.
          Re-run this installer from /home/<user>/ymir after the branch merges.
```

No behaviour changes for a normal install; a worktree install is honest about its own lifetime.

## Verified

```
bash -n bin/mail/install.sh        # syntax
bash bin/mail/install.sh           # unit active, /health answering, warning printed
systemctl --user is-enabled gna-desk.service   # enabled
```

**After the merge:** `bash bin/mail/install.sh` from `~/ymir`, once.
