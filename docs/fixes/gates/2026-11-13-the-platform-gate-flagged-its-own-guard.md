# gates · 2026-11-13 · The platform gate flagged its own guard

## What

The nightly NSR compliance round failed at 02:39 with `check_platform` — twelve "NON-PORTABLE" lines. Reading
them: three were *not uses at all*.

- `bin/gates/guards/pkill-guard.sh` — the guard whose job is to grep for `pkill`, reported for containing it.
- `bin/gates/guards.sh` — reported for naming that guard in its WARDS list.
- Three comment lines explaining the rule.

## Why

The scan asked *"does this line contain the word"*, not *"does this line run the command"*. A gate that counts
mentions will always flag its own documentation and its own guard — and a gate that cries twelve times when
three are real is a gate people learn to skim, which is worse than no gate.

## The fix

The scan now skips: comment lines, lines that search for the pattern (`grep`/`rg`/a `case` arm), the guard's own
file, and any use that carries a declared reason — `# kill: <why>` — because a blunt kill sometimes has no
graceful alternative, and then it must say why.

The one remaining `pkill` in a test now carries its reason: a fake Electron the test started seconds ago, matched
by its temp path, with no pid to name.

## What it still refuses, and should

Seven files call `kill -9` with no reason and no graceful attempt:

```
bin/engine/release-health.sh
bin/pi/opendesign.sh
systems/snotra/services/ear/snotra-live.sh
apps/bilskirnir/start.sh
apps/hvergelmir/just/free-port.sh
tests/e2e/arm-service-proof.sh
.agents/tests/syn-watch-arm-silent-exit.test.sh
```

Those are TRUE findings: a `kill -9` can leave a lock, a socket or a half-written state behind, and each of these
should either try a graceful kill first or declare why it cannot. Named here rather than silenced.

## Proof

```
$ bash .compliance/gates/check_platform.sh
[check_platform] NON-PORTABLE: ./bin/engine/release-health.sh uses 'kill -9'
… 7 files …
[check_platform] FAIL
```

Twelve findings became seven, and the seven are real.

## Change log

- **2026-11-13** — written with the change, after the nightly alarm.
