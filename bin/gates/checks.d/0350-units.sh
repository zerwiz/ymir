#!/usr/bin/env bash
# units — systemd reads every key in every unit template.
gate units      "systemd reads every key in every unit template" bash "$ROOT/bin/gates/checks/unit-template-check.sh" --quiet
