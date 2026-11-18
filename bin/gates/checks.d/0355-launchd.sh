#!/usr/bin/env bash
# launchd — the macOS service layer is proved, and its install step skips cleanly elsewhere.
#
# WHY THIS GATE (plan 293, 2026-11-16). `bin/engine/launchd-user.py` answers Ymir's
# `systemctl --user` verbs on a Mac by rendering each systemd user unit as a launchd agent, and
# `bin/engine/ymir-install.sh` step_launchd seats it. Neither had a test, so nothing noticed if the
# renderer drifted from `config/units.yaml`, if a verb stopped answering, or if the install step
# vanished from the chain. Both tests run without a Mac: a fake HOME and a fake launchctl for the
# renderer, and a copy of the real step under stubs for the install (RULES/05 — a clean skip is a
# pass, and it must say why).
gate launchd "the macOS layer renders config/units.yaml as launchd agents and its install step skips cleanly" \
     bash "$ROOT/bin/gates/checks/launchd-layer.sh"
