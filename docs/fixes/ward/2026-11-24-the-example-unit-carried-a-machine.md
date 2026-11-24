# The example unit carried a machine's own path

**Date:** 2026-11-24 · **Component:** ward (`bin/ward/garmr/garmr-hound.service.example`) ·
**Errand:** `private-scan`

## What was wrong

The sample unit for the hound's watchdog (added on 2026-11-23) gave its command line as a concrete
`/home/<user>/ymir-runtime/bin/ward/garmr/hound.py` — a real user of this fleet and the runtime pin as
it happens to stand on one machine.

That is what `RULES/04` forbids in the public repository: the engine, the tools and the templates ship;
a machine's own names and paths are read from the operator's home at install time. The twice-daily
agnostic audit said so plainly: one finding, one file, `:9`.

The example mattered beyond tidiness, because a person copies it. A template that spells one machine's
home teaches every reader to hardcode a different one.

## What changed

- The command line is now `__YMIR_ROOT__/bin/ward/garmr/hound.py`, the placeholder this repository
  already uses in `tools/mill/systemd/garmr-hound.service`.
- A header comment says where the real unit comes from: `bin/ward/garmr.sh install` renders
  `tools/mill/systemd/garmr-hound.service` and replaces `__YMIR_ROOT__` with the pinned runtime.

Nothing about the hound changed. The example still documents exactly what it documented before —
`WatchdogSec=120`, `Restart=always`, `NotifyAccess=main` — and no script reads it, so no install, no
service and no behaviour on any machine moves with this change.

The record of which machine the path named stays where it belongs: the home's deny list
(`hodd/identity/public-deny.txt`), which found it.

## Verify

    bash bin/gates/agnostic-audit.sh --ref origin/main   # before the fix: 1 finding, this file, :9
    bash bin/gates/agnostic-audit.sh                    # after it: verdict "CLEAN", 0 findings

The audit's entry and allow counts are read from the operator's own home, so the verdict and the
finding count are the facts to compare, not the totals.

## A path corrected, so the next reader finds it

The 2026-11-23 fix note (`docs/fixes/ward/2026-11-23-garmr-watchdog.md`) names the file without its
directory, as `bin/ward/garmr-hound.service.example`. The file has always lived at
`bin/ward/garmr/garmr-hound.service.example`. This note cites the old one and gives the path as it is.

## CHANGE LOG

- 2026-11-24 — the example unit loses the machine's path for the placeholder the installer renders.
