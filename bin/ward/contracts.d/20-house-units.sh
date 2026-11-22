#!/usr/bin/env bash
# No user unit of the house sits `failed`. Caught on 2026-11-22: housewatch.service failed on a second machine, and
# it was "installed and up" by every other check.
command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1 || { echo "skip: no user service manager here"; exit 0; }
failed="$(systemctl --user list-units --state=failed --plain --no-legend 2>/dev/null | awk '{print $1}' | tr '\n' ' ' | sed 's/ $//')"
[ -z "$failed" ] && { echo "ok: no user unit is failed"; exit 0; }
echo "red: failed: $failed — systemctl --user status <unit>; journalctl --user -u <unit> -n 30"; exit 1
