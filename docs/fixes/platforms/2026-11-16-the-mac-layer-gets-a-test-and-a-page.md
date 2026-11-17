# The macOS service layer gets a test, and the operator gets a page

**Date:** 2026-11-16 · **Component:** platforms · **Found while:** keeping the Mac layer after plan 293

## What went wrong

`bin/engine/launchd-user.py` answers Ymir's `systemctl --user` verbs on a Mac by rendering each
systemd user unit as a launchd agent. It arrived with 648 lines and no test anywhere, and the install
step that seats it (`bin/engine/ymir-install.sh` → `step_launchd`) had none either.

So nothing would have noticed if the renderer drifted away from `config/units.yaml`, if a verb stopped
answering, if a restart lost the wait that macOS needs before it will load the same label twice, or if
the step quietly left the install chain. And a Mac user had no page telling them the layer exists, what
it answers, or where the logs are.

## What changed

| File | Change |
|---|---|
| `bin/engine/tests/test_launchd_user.py` | Thirteen cases, no Mac needed. The real `config/units.yaml` entry is rendered through the one writer and the result is parsed back by `plistlib`: label, shell wrapper, environment, PATH order, log paths, `RunAtLoad`, `KeepAlive` from `Restart=`, `ThrottleInterval` from `RestartSec=`, and an interval agent from a `timer` entry. Then every verb answers against a fake HOME and a fake `launchctl` — enable/disable with `--now`, start/stop/restart, is-active/is-enabled/is-failed, status, `show -p` and `--value`, cat, list-units, list-unit-files, `daemon-reload` re-rendering an edited unit — with systemctl's exit codes 0, 1, 3, 4. A restart is proved to wait for the old agent to leave before loading the new one. The file is also run as a program, and as `systemd-run` by its own name, which renders a transient agent. |
| `bin/engine/tests/test_launchd_step_skips.sh` | The install step, extracted from the real installer and driven under stubs: on Linux it is a named clean skip (`"launchd","SKIP","not a Mac — systemd runs the units here"`, in a check run and a real run) and it seats nothing; on a Mac (a stubbed `uname`) it links `systemctl` and `systemd-run` at the renderer, reports OK, and reads the seat back as answered. It also refuses a step that is defined but never run, or moves below the runtime step. |
| `bin/gates/checks/launchd-layer.sh` + `bin/gates/checks.d/0355-launchd.sh` | Both suites as one CI gate. A test no gate runs is a test nobody runs. |
| `docs/features/ymir-on-a-mac.md` | The operator page: what the layer is, the bash floor, the commands, which units become which agents, where the logs are, and the limits a person will meet — a `.socket` is not rendered, a calendar timer is hourly or daily rather than at the time it names, only the user manager exists. |
| `docs/features/_catalogue/entries/00-026-ymir-on-a-mac.md` | The catalogue row, woven with `bin/records/weave-features.sh`. |

## How it was proved

On Linux, with no Mac in the room:

```
bash bin/gates/checks/launchd-layer.sh --verbose
  ok   launchd-user.py renders the register and answers the verbs
       Ran 13 tests … OK
  ok   step_launchd skips cleanly off a Mac and seats on one
       ok   step_launchd (CHECK=0) clean-skips on Linux with its named line
       ok   on a Mac step_launchd seats systemctl --user as launchd
       ok   step_launchd is called by run_step in the install chain
       all cases held
```

`bash bin/gates/guards/features-guard.sh` reports `every feature page is catalogued, and the woven
catalogue is current`.

## What is still open

The layer itself has only been measured on one Mac (Apple silicon, macOS 14.7, eleven units answering on
loopback). These tests hold the renderer and the verbs against a fake `launchctl`; they cannot prove
launchd's own behaviour on a macOS release nobody has run it on. A seat on a second Mac release is still
owed.
