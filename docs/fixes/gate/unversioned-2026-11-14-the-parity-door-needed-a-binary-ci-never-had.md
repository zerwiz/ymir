# gate · unversioned · 2026-11-14 — the parity door needed a binary CI never had

The `opencode-launcher` gate was red on `main` and green on every developer box. That asymmetry is the
whole story: door 2 of `bin/gates/tests/test_opencode_launcher.sh` runs
`bin/agents/einherjar-spawn.sh … --dry-run`, and the spawner checks that the harness executable exists
**even for a dry run**. CI has no `opencode`; a dev box has one.

The file's own header says it *"needs no model turn and no opencode binary (the check is proved against a
stub)"*. Door 2 was the one place that was not true.

## What changed

- **Door 2 is given a stub `opencode` on `PATH`.** A dry run only prints its plan, so a stub is exactly
  what the door needs; the spawner's real guard (never seat a harness that cannot start) is untouched and
  still applies to a real spawn.
- **A dry run no longer aborts at its last line.** Measured while proving this: with a stub `opencode`,
  `einherjar-spawn.sh --dry-run` printed the whole plan and then died with
  `line 883: REUSE_PANE: unbound variable`, because that name was initialised *inside* the `--relaunch`
  branch while the dry-run block prints `seat:` for every spawn. `REUSE_PANE`/`REUSE_WS` are now
  initialised before the branch, so a dry run exits 0 as a dry run should.

> [!NOTE]
> The one-agent-per-id seat guard (`herdr pane list`) still sits inside the `--relaunch` branch, as it did
> before this mend. That is unchanged on purpose — moving it changes what a *fresh* spawn refuses, which
> is a decision for the plan that owns the guard, not for a gate mend. It is written down here so the next
> hand does not have to find it again.

## Proof

```text
$ env -i HOME=/tmp/cihome PATH=/usr/local/bin:/usr/bin:/bin bash bin/gates/tests/test_opencode_launcher.sh
ok   einherjar-spawn --dry-run prints the launcher's line (opencode run --model M --auto <brief>)
…
all ok
```

(before: `FAIL einherjar-spawn --dry-run prints the launcher's line … got: ""`, `1 failed`)

## Files

- `bin/gates/tests/test_opencode_launcher.sh`
- `bin/agents/einherjar-spawn.sh`

## CHANGE LOG

- 2026-11-14 — written with the mend; the test stops depending on an installed binary, the dry run stops
  crashing on an unset name.
