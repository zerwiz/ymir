# Ymir on a Mac

## What it is

A Mac has no systemd. Ymir's services — the halls, the well, the MCP doors, the
scheduled jobs — are systemd user units, and about sixty places in the tree start
them with `systemctl --user`. On macOS nothing ran them, so an install wrote the
units and then sat there with every port dark.

The macOS service layer closes that gap without a second Ymir. It reads the same
unit files that Linux reads, renders each one as a launchd agent, and answers the
`systemctl --user` verbs Ymir already calls. The core stays one core; the platform
layer is the shim beneath it.

The install seats it for you. This page is what to run when you want to look at
it, and how to read what it says.

## What you need

- **bash 4 or newer.** macOS ships bash 3.2, and the doctor, the migrations and the
  gates need a newer one. Run `brew install bash` once. You do not need to change
  your login shell — those scripts find Homebrew's bash themselves, or take the one
  you name in `YMIR_BASH`.
- **python3** — the layer is written in it. The Xcode command line tools carry one;
  if the step reports it missing, `xcode-select --install` is the fix.
- **Nothing else.** No Homebrew service, no root, no daemon of Ymir's own.

## Do it

Seat the layer:

```bash
bin/engine/launchd-ensure.sh ensure
```

That puts one file on your PATH, `~/.local/bin/systemctl`, pointing at
`bin/engine/launchd-ensure.sh`'s target — the renderer, `bin/engine/launchd-user.py`.
The same file also answers to the name `systemd-run`, which is how Ymir starts a
one-off job. It never shadows a real `systemctl`: if a system manager is already
there, the door says so and leaves it alone.

Ask it what it did:

```bash
bin/engine/launchd-ensure.sh check      # exit 0 seated, 1 not
bin/engine/launchd-ensure.sh remove     # take the shim away
```

Then drive Ymir as on any other machine — `systemctl --user start mimir` reaches
launchd, and so does `ymir raise`, because both take the same road.

An install runs the same door as its `launchd` step, so a normal install needs none
of this by hand. Off a Mac the door is a clean skip: it prints why and exits 0.

## What it answers

The verbs Ymir actually calls, with systemctl's own exit codes (0 yes or ok, 1 no or
failed, 3 not active, 4 no such unit):

`enable` · `disable` (both take `--now`) · `start` · `stop` · `restart` ·
`try-restart` · `reload-or-restart` · `is-active` · `is-enabled` · `is-failed` ·
`status` · `show` · `cat` · `list-units` · `list-unit-files` · `daemon-reload` ·
`show-environment` · `reset-failed`. `import-environment`, `set-environment`,
`mask` and `preset` are accepted and do nothing, so a script that calls them is not
stopped by a missing verb.

How a unit becomes an agent:

| Ymir's unit | The launchd agent |
|---|---|
| `X.service` | `org.ymir.X` in `~/Library/LaunchAgents`, starting at login |
| `X.timer` with `OnUnitActiveSec=` | `org.ymir.X` with `StartInterval`, running `X.service`'s command |
| a `.target` | its `<target>.wants/` directory, exactly as systemd keeps it |
| enabled | the plist sits in `~/Library/LaunchAgents` |
| started, not enabled | the plist is loaded from `~/Library/Application Support/ymir/launchd`, so it does not follow you into the next login |

Every agent's output goes to `~/Library/Logs/ymir/<unit>.log`. Agents run with
`ProcessType` `Standard`: with `Background` macOS throttles a job to almost no CPU,
and every service was measured sitting at 0% with no port open.

## Notes and limits

- **A `.socket` or a `.path` unit is not rendered.** Services, timers and targets
  are; a unit that is only a socket has nothing to start.
- **A calendar timer is approximated.** `OnCalendar=hourly` runs hourly and any
  other calendar expression runs daily; it does not fire at the time the
  expression names. Ymir's own jobs use `OnUnitActiveSec=`, which is exact.
- **`OnBootSec` under two minutes counts as "start at login".** Anything longer is
  left to launchd's own throttling.
- **Only the user manager exists here.** A call without `--user` is refused rather
  than silently served by the wrong manager.
- **The shim is one symlink.** If `~/.local/bin/systemctl` exists and is not Ymir's,
  the seat refuses and asks you to move it aside instead of overwriting it.
- **The layer is tested without a Mac.** `bin/gates/checks/launchd-layer.sh --verbose`
  runs both suites: the renderer against a fake home and a fake `launchctl`, and the
  install step against a stubbed `uname`. They run in the CI gate, so a change to
  the register or to a verb is judged on Linux before it ever reaches your Mac.

## If it does not work

Start with the door, which names the fault rather than nodding:

```bash
bin/engine/launchd-ensure.sh check
```

A `FAIL` row there means the shim is not seated or `python3` is missing. If the
shim is seated and a service is still dark, ask launchd directly:

```bash
launchctl print gui/$(id -u)/org.ymir.mimir
tail -40 ~/Library/Logs/ymir/mimir.log
```

The log is the program's own output — a Python or bash error in it is the real
fault, not launchd. If you see `Bootstrap failed: 5: Input/output error` after a
restart, you are on an older tree: launchd needs a moment after unloading before it
accepts the same label again, and the layer waits for it.

To prove a fault is the layer's and not your machine's, run the gate:
`bin/gates/checks/launchd-layer.sh --verbose`.

## The files

| Path | What it is |
|---|---|
| `bin/engine/launchd-user.py` | the renderer and the verbs |
| `bin/engine/launchd-ensure.sh` | `check` · `ensure` · `remove` — seats the shim |
| `bin/engine/ymir-install.sh` | its `launchd` step |
| `config/units.yaml` | the one register of what is installed; the renderer reads the units written from it |
| `bin/engine/tests/test_launchd_user.py` | the renderer and the verbs, with a fake home |
| `bin/engine/tests/test_launchd_step_skips.sh` | the install step: a named skip off a Mac, the seat on one |

## CHANGE LOG

- **2026-11-16** — Opened: what a Mac install does, the launchd step, and how to check it.
