#!/usr/bin/env bash
# 0023-wardens-per-machine — record what THIS machine's wardens do today, so nothing stops and a fresh
# install starts with every door off.
#
# WHY (plan 290 §3 and §4 P2; the Allfather, 2026-11-14). A warden is seated by ROLE, so every machine
# that installed Ymir got the same outward doors — a merging warden among them — and one such install
# merged pull requests into `zerwiz/ymir` under a GitHub account this fleet does not own. From 0023 on,
# an outward door runs only where the operator's home names it for THAT machine:
#
#     $YMIR_HOME/config/machines/<machine>/wardens.yaml     `enabled: on` per door, absent = off
#
# The change is safe only if it is not a silent switch-off, so this migration RECORDS what each machine
# already does and writes it as `enabled: on`. What it never does:
#
#   · it never turns anything ON that is not already running (a disabled, inactive timer stays off);
#   · it never writes `merge: on` — the heart's own holder sets that, and the library refuses it on any
#     machine the fleet does not name as heart;
#   · it never removes a key, a comment or a decision already in the file: an `enabled:` a person wrote is
#     left exactly as it is, and only a MISSING one is added;
#   · it never touches another machine's file.
#
# A home with no file at all gets one, with every door off except the ones this machine is running now.
# That is why a collaborator's fresh install — which runs no door yet — seats nothing outward.
#
# Idempotent: applied once, and a second run changes nothing (it is also recorded in state/migrations).
#
# 2026-11-14, later the same day — THIS MIGRATION ONLY RECORDS; 0024 DECIDES. At the Allfather's word
# (*"users must get these updates on installations"*) migration 0024 runs right after this one and turns
# every outward door OFF on every existing installation, stopping the timers this one merely described and
# recording `was_on:` so the operator can turn back on what he owns. Kept, not rewritten, because a home may
# already have applied it (RULES/06).
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOME_DIR="${YMIR_HOME:-}"
if [ -z "$HOME_DIR" ] && [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  # shellcheck source=bin/vault/hoard-lib.sh
  . "$ROOT/bin/vault/hoard-lib.sh"
  ymir_home_root HOME_DIR 2>/dev/null || HOME_DIR=""
fi
HOME_DIR="${HOME_DIR:-${YMIR_HOME:-}}"
[ -n "$HOME_DIR" ] || { printf '0023-wardens-per-machine: no home recorded — nothing to migrate\n'; exit 3; }

POLICY="$ROOT/bin/forge/warden-policy.py"
[ -r "$POLICY" ] || { printf '0023-wardens-per-machine: bin/forge/warden-policy.py is missing in this tree\n' >&2; exit 1; }

MACHINE="$(python3 -I "$POLICY" name 2>/dev/null)"
[ -n "$MACHINE" ] || { printf '0023-wardens-per-machine: this machine cannot be named from the fleet registry\n' >&2; exit 3; }

# This machine's roles, from the one resolver (Rule 07): env, then the registry, then the documented body.
ROLES="${YMIR_UNITS_ROLES:-${YMIR_ROLE:-}}"
if [ -z "$ROLES" ] && [ -x "$ROOT/bin/skuld/role.sh" ]; then
  ROLES="$(bash "$ROOT/bin/skuld/role.sh" resolve 2>/dev/null | tr -d '[:space:]')"
fi
ROLES="${ROLES:-dev}"

DOORS_DIR="$HOME_DIR/config/machines/$MACHINE"
FILE="$DOORS_DIR/wardens.yaml"

if [ "${YMIR_MIGRATE_DRY:-0}" = 1 ]; then
  printf '0023-wardens-per-machine: would record %s roles=%s into %s\n' "$MACHINE" "$ROLES" "$FILE"
  exit 0
fi
mkdir -p "$DOORS_DIR" || { printf '0023-wardens-per-machine: cannot create %s\n' "$DOORS_DIR" >&2; exit 1; }

# ── what this machine does TODAY ────────────────────────────────────────────
# A door is "on today" when its clock is running: a user timer that is active or enabled, or a cron row
# whose role gate this machine satisfies. `systemctl` absent (Termux, macOS, a container) is not an
# error: then only the unit file's presence and the cron row can speak, and the row says so.
python3 - "$ROOT" "$HOME_DIR" "$MACHINE" "$ROLES" "$FILE" <<'PY'
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

root, home, machine, roles_csv, target = sys.argv[1:6]
roles = {r for r in re.split(r"[\s,]+", roles_csv) if r}
home = Path(home)
target = Path(target)

# The door → what runs it, so this migration cannot drift from the doors themselves.
TIMER_UNITS = {
    "queue-warden": "queue-warden.timer",
    "review-watch": "review-watch.timer",
    "review-seat": "review-seat.timer",
    "review-loop": "review-loop.timer",
    "pr-watch": "pr-watch.timer",
    "issue-watch": "issue-watch.timer",
    "ship-watch": "ship-watch.timer",
}
CRON_SCRIPTS = {
    "gna-mail": "bin/time/nornir-job-gna-mail.sh",
    "snotra-mail": "bin/time/nornir-job-snotra-mail.sh",
    "git-sync": "bin/time/nornir-job-git-sync.sh",
    "private-scan": "bin/time/nornir-job-private-scan.sh",
}
# Doors a hand invokes are never seated, so their `on` is on by nature: they are not written here.

def systemctl(*args):
    if not shutil.which("systemctl"):
        return None
    try:
        return subprocess.run(["systemctl", "--user", *args], capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        return None

unit_dir = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "systemd" / "user"

def timer_running(unit):
    r = systemctl("is-active", unit)
    if r is not None and r.stdout.strip() == "active":
        return True, "timer active"
    r = systemctl("is-enabled", unit)
    if r is not None and r.stdout.strip() in ("enabled", "enabled-runtime", "static"):
        return True, "timer enabled"
    if r is None and (unit_dir / unit).exists():
        return True, "unit file present (no systemctl here to ask)"
    return False, "not running"

def cron_row(script):
    path = home / "config" / "cron.yaml"
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return False, "no config/cron.yaml"
    known_roles = {"heart", "forge", "dev", "hand"}
    for line in lines:
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        if script not in s:
            continue
        # A row is `<shape>\s+<command>` or `<shape>\s+@role\s+<command>`, and the role token may sit on
        # either side of the time (both are legal). Only a token naming a ROLE gates; `@daily`, `@hourly`
        # and `@hourly:20` are shapes and gate nothing.
        gate = ""
        for token in s.split()[:3]:
            if token.startswith("@") and any(r in known_roles for r in token[1:].split(",")):
                gate = token[1:]
                break
        if not gate or (roles & {g for g in gate.split(",") if g}):
            return True, f"cron row gate={'@'+gate if gate else 'any'}"
        return False, f"cron row is @{gate}, this machine is {'/'.join(sorted(roles)) or 'unknown'}"
    return False, "no cron row"

# ── what is in the file already ─────────────────────────────────────────────
existing = target.read_text(encoding="utf-8") if target.exists() else ""
lines = existing.splitlines()

def block_state(door):
    """(block present, `on` already written) for a door, by scanning the file's own lines."""
    present, has_on, in_block = False, False, False
    for line in lines:
        if re.match(rf"^{re.escape(door)}\s*:", line):
            present = True
            in_block = True
            if re.match(rf"^{re.escape(door)}\s*:\s*(on|off|true|false|yes|no)\b", line):
                has_on = True
            continue
        if in_block:
            if line.strip() == "" or line.lstrip().startswith("#"):
                continue
            if not line.startswith((" ", "\t")):  # a new top-level key ends the block
                in_block = False
                continue
            if re.match(r"^\s+(enabled|on)\s*:", line):
                has_on = True
    return present, has_on

plan = {}
for door, unit in TIMER_UNITS.items():
    on, why = timer_running(unit)
    plan[door] = (on, why)
for door, script in CRON_SCRIPTS.items():
    on, why = cron_row(script)
    plan[door] = (on, why)

added, kept = [], []
out = list(lines)
if not out:
    out = [
        f"# wardens.yaml — {machine}'s own wardens (plan 290 §3). Written by migration 0023 on its first",
        "# run, recording what this machine already did so nothing stops. Edit it by hand from here: a door",
        "# is seated only where this file names it `on`, `merge: on` is refused on any machine the fleet does",
        "# not name as heart, and every outward act is carved as one Rune.",
        "",
    ]

for door, (on, why) in plan.items():
    present, has_on = block_state(door)
    value = "on" if on else "off"
    if present and has_on:
        kept.append(f"{door} (already written)")
        continue
    if present:
        # insert `on:` as the first key of the existing block, keeping every comment and key in place
        for i, line in enumerate(out):
            if re.match(rf"^{re.escape(door)}\s*:", line):
                if re.match(rf"^{re.escape(door)}\s*:\s*\S", line):
                    out[i] = f"{door}:"
                out.insert(i + 1, f"  enabled: {value}   # recorded by migration 0023 — {why}")
                break
        added.append(f"{door}: {value} ({why})")
    else:
        out += ["", f"{door}:", f"  enabled: {value}   # recorded by migration 0023 — {why}"]
        added.append(f"{door}: {value} ({why})")

# merge is never turned on by a migration (plan 290 P1): the heart's own holder writes it, past its
# merge-verdict gate. A missing key is written as off so the file states the decision out loud.
if not any(re.match(r"^\s+merge\s*:", ln) for ln in out):
    for i, line in enumerate(out):
        if re.match(r"^queue-warden\s*:", line):
            out.insert(i + 1, "  merge: off   # only the machine the fleet names as heart may say on")
            added.append("queue-warden: merge off")
            break

text = "\n".join(out).rstrip("\n") + "\n"
if text == existing:
    print(f"0023-wardens-per-machine: {target} already records this machine — nothing changed")
else:
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8")
    print(f"0023-wardens-per-machine: recorded {machine} (roles {','.join(sorted(roles)) or 'unknown'}) in {target}")
    for a in added:
        print(f"  set {a}")
    for k in kept:
        print(f"  kept {k}")
PY
rc=$?
[ "$rc" = 0 ] || { printf '0023-wardens-per-machine: the recording failed (%s)\n' "$rc" >&2; exit 1; }

# ── and what is NOT seated stays not seated ────────────────────────────────
# Seating itself is `bin/engine/units.py`'s decision on the next install/update (it reads this file), and
# each door's own --install-timer asks `warden_seat_allowed`. This migration starts nothing and stops
# nothing: a change to what runs on a machine is the operator's, never a migration's.
printf '0023-wardens-per-machine: no timer was started or stopped — seating reads %s from now on\n' "$FILE"
exit 0
