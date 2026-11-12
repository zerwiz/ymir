# Atomic releases — the apps run from a release, never from a moving tree

## What it is

An update should never move the code under an open window. So the apps do not run
from `~/ymir` at all: they run from a **release**, and a single symlink names the
live one.

A release is `~/ymir-releases/<sha>/` — one commit's tree, its symlinks resolved
into real files, its dependencies installed inside it, its assets built inside it,
and a manifest that names its own sha. It is read-only in spirit: everything that
must survive (state, logs, pids, the hoard, the vault) lives on a **shared shelf**
at `~/ymir-shared` that every release links to.

`~/ymir-current` points at exactly one release. Flipping that link — one rename,
health-checked first — is what makes a new build live, and flipping it back is the
rollback. Going live and rolling back are the same pointer change.

Three doors:

- `bin/engine/release-build.sh <sha>` — forge a release from a commit.
- `bin/engine/release-health.sh <dir>` — can *that directory* serve the apps?
- `bin/engine/release-flip.sh <sha>` — health first, then move the link, then watch.

## What you need

- A git checkout (the build exports a commit with `git archive`).
- `npm` for the dependency closure; `bun` for the gate and the Smíðja visualizer.
  Without them the doors say so and skip — they never pretend they checked.
- Disk: a release carries its dependencies (hundreds of MB). Three are kept.

## Do it

```bash
bin/engine/release-build.sh HEAD        # forge ~/ymir-releases/<sha>/
bin/engine/release-health.sh ~/ymir-releases/<sha> --live   # prove it can serve
bin/engine/release-flip.sh <sha>        # health, flip, then watch for a window
bin/engine/release-flip.sh --status     # where the world points, and the shelf
```

`release-health.sh --live` raises the release's own gate, SPA, visualizer and hall on
probe ports (canonical + 10000), proves each answers, proves the gate reports *this*
directory as the root it serves, then stops them. Without `--live` it proves the
static shape and reports who is serving the canonical ports today.

`release-flip.sh` refuses to move the link when health refuses, records every flip in
`~/.local/state/ymir/releases.log`, and — if the release it just made live degrades
inside its check window — flips back on its own and records `rolled back to <old>`
with the reason.

## Notes and limits

- **The swap is one rename.** `ln -s <release> ~/ymir-current.tmp && mv -T
  ~/ymir-current.tmp ~/ymir-current`. A `rm` before the `ln` is forbidden: it leaves
  a window where nothing is current.
- **Build and health happen entirely off to the side.** The flip is the last act, so a
  failed build or a failed check never costs you the release that is live.
- **Retention is three, pruned by age BEFORE a build** — never after a failure, so the
  release you would roll back to is still there.
- **Processes keep the release they started in.** Restarting an app is a decision, not
  a side effect of an update. Your desktop windows are never restarted under you.
- **Nothing points at the symlink yet.** Re-seating launchers and units to
  `~/ymir-current` is the next phase of plan 221; until then the flip is proved, not
  in use.
- **No containers here.** A container runtime is a later phase, and this machine has
  none installed.

## If it does not work

- `release-health.sh` names the failing row and the surface. A refused release never
  becomes current; the link does not move.
- `release-flip.sh --status` shows the current target, every release on the shelf with
  its size and age, and the last five log lines.
- If the log says `result=rolled-back`, the reason is on the same line — fix that
  before building again.
- `release-build.sh --prune-only` prunes without building, and never removes the
  current release.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
