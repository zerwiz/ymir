# The apps run from main, never from a worktree

**2026-11-08 · component: desktop · the Allfather's word**

## The law he gave

*"they all ned to point to main and the updater needs to pull main the apps run time must be locked to main.
otherwise they might break if the user are swithing threes"* — and the same hour it had already broken so.

## What happened

Five launcher entries pointed into a worktree:

```
rodd               Exec=/home/zerwizomar/ymir/.yggdrasil/areas-of-a-project/apps/rodd/start.sh
ymir-sessrumnir    Exec=bash …/.yggdrasil/areas-of-a-project/bin/desktop/sessrumnir-launch.sh start
ymir-hlidskjalf    Exec=bash …/.yggdrasil/areas-of-a-project/scripts/electron.sh start --view hlidskjalf
ymir-odrerir       Exec=bash …/.yggdrasil/areas-of-a-project/scripts/electron.sh start --view odrerir
ymir-smidja        Exec=bash …/.yggdrasil/areas-of-a-project/scripts/electron.sh start --view smidja
```

Every desktop button therefore opened a working copy that a session deletes when the errand ends — and that
had no installed Electron at all (`desktop-verify`: *"no executable Electron runtime — the resolver found
nothing"*). The cause was `scripts/start.sh` / the Omarchy layer being run **inside** a worktree: whatever
tree writes the entries becomes the tree the buttons point at.

## The three pieces of the lock

```
lock[3]{piece,path,what it does}:
  "the resolver","bin/desktop/main-tree.sh","`git rev-parse --git-common-dir` names the canonical checkout; `--check` exits 1 inside a worktree. A caller that cannot resolve it refuses instead of guessing"
  "the lock, at the writer","bin/desktop/design-icon.sh","the ONE place an `Exec=` line is written. A path containing `/.yggdrasil/` is rewritten to the canonical tree and the rewrite is said aloud, so no caller can seat a launcher into a working copy"
  "the ward","bin/gates/guards/desktop-main-guard.sh","judges the INSTALLED shelf (the launcher shelf): any ymir entry whose Exec points into a worktree is refused, with the one command that fixes it. Skips cleanly where nothing is installed"
```

Wired into `bin/gates/guards.sh` (44 wards). And the scheduled updater's brief now carries the law: after
Gróa runs, check `desktop-verify.sh` and `desktop-main-guard.sh`, and re-seat from `main-tree.sh` if either
complains — `· desktop ok` or `· desktop RE-SEATED` in its one line.

## Verified

```
bin/desktop/main-tree.sh /…/.yggdrasil/areas-of-a-project   → /home/zerwizomar/ymir
bin/desktop/main-tree.sh --check /…/.yggdrasil/areas-of-a-project → "this is a WORKTREE", exit 1
bin/gates/guards/desktop-main-guard.sh                      → 5 launcher(s), every one seated from a real tree
grep -l yggdrasil over the launcher shelf (the entries)   → nothing
```

All five entries now read `/home/zerwizomar/ymir/…`, re-seated from the main tree with
`bin/host/omarchy-install.sh`.

## CHANGE LOG

- **2026-11-08** — Opened with the law, the five broken entries, the resolver, the lock at the Exec writer,
  the ward, and the updater's new desktop step.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: the heart's user. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).
