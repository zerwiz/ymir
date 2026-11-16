# The release road runs on a Mac

**Date:** 2026-11-16 · **Component:** platforms / runtime · **Found while:** moving a Mac's pin onto the release road

## What went wrong

On the release road, every update builds a release beside the running one, builds the apps inside it, proves it and
then flips the link. A Mac could not use it:

| Where | Fault | Effect on a Mac |
|---|---|---|
| `bin/engine/release.sh` | `mv -T` and `date -Is` are GNU-only | `adopt`, `build` and `flip` failed at their first move |
| `bin/engine/release.sh` `in_use` | read `/proc` only | saw no process at all, so a release still serving could be pruned |
| `bin/engine/release-services.sh` | read `/proc/<pid>` only | could not tell which release a service ran from |

Without the release road, the pin was moved in place and nothing built the apps. Hlidskjalf's and Smíðja's pages were
missing in the runtime, so their windows stayed empty.

## What changed

- `release.sh` has `mv_t`, which runs `mv -T` on GNU and `mv -fh` on BSD/macOS, and `now_iso`, a timestamp both
  `date`s accept.
- `in_use` and `proc_release` ask `lsof` for a working directory and `ps` for a command line where `/proc` is absent.

Linux behaviour is unchanged.

## How it was proved

On one Mac (Apple silicon, macOS 14.7), `release.sh adopt` turned `~/ymir-runtime` into a link to
`~/.local/share/ymir/current`. `runtime-deploy.sh` then built the release with the apps inside it.

## CHANGE LOG

- 2026-11-15 — review-mend: added missing heading for #784
