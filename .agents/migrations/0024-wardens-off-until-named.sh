#!/usr/bin/env bash
# 0024-wardens-off-until-named — no outward warden runs on any installation until the operator names it
# for THAT machine.
#
# WHY (the Allfather, 2026-11-14): *"users must get these updates on installations."* Migration 0023 only
# RECORDED what a machine was doing, which left every existing install acting outward by inertia — the very
# inertia that let a collaborator's install merge pull requests into this repository. So the law is applied
# the other way round: an outward door is OFF until a person writes `enabled: on` beside it in
#
#     $YMIR_HOME/config/machines/<machine>/wardens.yaml
#
# What this migration does, on every home it reaches (a fresh install runs it too, through
# `bin/engine/ymir-migrate.sh apply` in the installer and in Gróa's update):
#
#   1. seats the template if this machine has no file at all (every door off);
#   2. turns every outward door OFF, and where the value in the file was put there by a migration rather
#      than by a person it rewrites that value;
#   3. records `was_on: <date>` for every door the OLD INSTALL was actually running — asked of systemd, not
#      of the file, because on an old-shaped home there is no file to ask — so the operator can turn back on
#      what he owns;
#   4. STOPS AND DISABLES every outward warden timer the old install seated, keeping its unit file, so one
#      `systemctl --user enable --now <unit>` restores it the moment the file names it;
#   5. touches nothing else: another machine's file is never read, no unit is deleted, no door is removed.
#
# What it deliberately does NOT do:
#   · it never overwrites an `enabled:` a PERSON wrote — a line carrying no migration marker is left exactly
#     as it is, and that door's timer is not touched;
#   · it never writes `merge: on` (only the machine the fleet names heart may reach a merge at all);
#   · it never deletes a unit file or a comment.
#
# Idempotent: a second run finds the markers in place and changes nothing.
#
# Usage: 0024-wardens-off-until-named.sh            (run by bin/engine/ymir-migrate.sh apply)
# Env (the test seams the unit writer already uses): YMIR_HOME · YMIR_MACHINE · YMIR_UNIT_DIR ·
#      YMIR_UNITS_NO_SYSTEMCTL=1 · YMIR_MIGRATE_DRY=1
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOME_DIR="${YMIR_HOME:-}"
if [ -z "$HOME_DIR" ] && [ -r "$ROOT/bin/vault/hoard-lib.sh" ]; then
  # shellcheck source=bin/vault/hoard-lib.sh
  . "$ROOT/bin/vault/hoard-lib.sh"
  ymir_home_root HOME_DIR 2>/dev/null || HOME_DIR=""
fi
HOME_DIR="${HOME_DIR:-${YMIR_HOME:-}}"
[ -n "$HOME_DIR" ] || { printf '0024-wardens-off-until-named: no home recorded — nothing to do\n'; exit 3; }

POLICY="$ROOT/bin/forge/warden-policy.py"
TEMPLATE="$ROOT/.agents/config/machine-wardens.example.yaml"
[ -r "$POLICY" ] || { printf '0024-wardens-off-until-named: bin/forge/warden-policy.py is missing in this tree\n' >&2; exit 1; }

MACHINE="$(python3 -I "$POLICY" name 2>/dev/null)"
[ -n "$MACHINE" ] || { printf '0024-wardens-off-until-named: this machine cannot be named from the fleet registry\n' >&2; exit 3; }

FILE="$HOME_DIR/config/machines/$MACHINE/wardens.yaml"
TODAY="$(date +%Y-%m-%d)"

if [ "${YMIR_MIGRATE_DRY:-0}" = 1 ]; then
  printf '0024-wardens-off-until-named: would seat %s and stop every outward warden timer this machine was running\n' "$FILE"
  exit 0
fi

mkdir -p "$(dirname "$FILE")" || { printf '0024-wardens-off-until-named: cannot create %s\n' "$(dirname "$FILE")" >&2; exit 1; }

# ── 1 · a home with no file receives the template, every door off ───────────
if [ ! -f "$FILE" ]; then
  [ -r "$TEMPLATE" ] || { printf '0024-wardens-off-until-named: the template %s is missing\n' "$TEMPLATE" >&2; exit 1; }
  {
    printf '# Written by migration 0024 on %s: this machine runs no outward warden until a person names one\n' "$TODAY"
    printf '# on in this file (`enabled: on`). The unit files the old install seated are still on disk, so naming a\n'
    printf '# door here and running `systemctl --user enable --now <door>.timer` restores it.\n'
    printf '#\n'
    printf '# Template source: .agents/config/machine-wardens.example.yaml\n\n'
    cat "$TEMPLATE"
  } | sed 's/^\([[:space:]]*\)enabled:[[:space:]]*off.*$/\1enabled: off   # migration 0024 — off until this machine names it/' \
    >"$FILE" || { printf '0024-wardens-off-until-named: cannot write %s\n' "$FILE" >&2; exit 1; }
  printf '0024-wardens-off-until-named: seated the template at %s (every outward door off)\n' "$FILE"
fi

# ── 2, 3 and 4 · turn the doors off, record what ran, stop the clocks ───────
python3 - "$FILE" "$TODAY" <<'PYTHON'
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

target, today = Path(sys.argv[1]), sys.argv[2]

# The outward doors this migration governs, and the clock each one runs as (None where a Nornir job, not a
# timer, is what seats it). A migration carries its own copy of the list on purpose: it must still know what
# to turn off after the code has moved on.
DOORS = [
    ("queue-warden", "queue-warden.timer"),
    ("review-watch", "review-watch.timer"),
    ("review-seat", "review-seat.timer"),
    ("review-loop", "review-loop.timer"),
    ("pr-watch", "pr-watch.timer"),
    ("issue-watch", "issue-watch.timer"),
    ("ship-watch", "ship-watch.timer"),
    ("gna-mail", None),
    ("snotra-mail", None),
    ("git-sync", None),
    ("private-scan", None),
]
UNITS = dict(DOORS)
MARKERS = ("migration 0023", "migration 0024")   # a value a migration put there, not a person


def systemctl(*args):
    if os.environ.get("YMIR_UNITS_NO_SYSTEMCTL") == "1" or not shutil.which("systemctl"):
        return None
    try:
        return subprocess.run(["systemctl", "--user", *args], capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return None


def clock_running(unit):
    """Did the OLD INSTALL seat this clock? Asked of systemd — the file cannot know: on an old-shaped home
    there is no file at all, and an installation that never made a decision must not be assumed to have.

    True = running, False = asked and it is not, None = there is no systemd here to ask.
    """
    if unit is None:
        return False          # a Nornir job: nothing on this machine to stop
    active, enabled = systemctl("is-active", unit), systemctl("is-enabled", unit)
    if active is None and enabled is None:
        return None           # could not ask
    if active is not None and active.stdout.strip() == "active":
        return True
    if enabled is not None and enabled.stdout.strip() in ("enabled", "enabled-runtime", "static"):
        return True
    return False


text = target.read_text(encoding="utf-8")
lines = text.splitlines()


def block_range(door):
    start = None
    for i, line in enumerate(lines):
        if re.match(rf"^{re.escape(door)}\s*:", line):
            start = i
            break
    if start is None:
        return None
    for j in range(start + 1, len(lines)):
        if lines[j].strip() == "" or lines[j].lstrip().startswith("#"):
            continue
        if not lines[j].startswith((" ", "\t")):
            return (start, j)
    return (start, len(lines))


def find(rng, key):
    if rng is None:
        return None
    for i in range(rng[0] + 1, rng[1]):
        if re.match(rf"^\s+{key}\s*:", lines[i]):
            return i
    return None


was_running = {door: clock_running(unit) for door, unit in UNITS.items()}
out = list(lines)
set_off, kept = [], []

for door in UNITS:
    rng = block_range(door)
    if rng is None:
        out += ["", f"{door}:", "  enabled: off   # migration 0024 — off until this machine names it"]
        lines = out
        set_off.append(f"{door}: off (added)")
    else:
        idx = find(rng, "enabled")
        if idx is None:
            idx = find(rng, "on")
        if idx is None:
            out.insert(rng[0] + 1, "  enabled: off   # migration 0024 — off until this machine names it")
            lines = out
            set_off.append(f"{door}: off (added)")
        else:
            line = out[idx]
            value = line.split(":", 1)[1].split("#", 1)[0].strip().lower()
            if not any(marker in line for marker in MARKERS):
                kept.append(f"{door}: {value or 'unset'} (written by a person — left alone)")
                continue
            key = line.split(":", 1)[0]
            out[idx] = f"{key}: off   # migration 0024 — off until this machine names it"
            lines = out
            set_off.append(f"{door}: off" + (f" (was {value})" if value not in ("off", "") else ""))
    # record what the old install had seated, so the operator can turn back on what he owns
    if was_running.get(door):
        rng2 = block_range(door)
        if rng2 is not None and find(rng2, "was_on") is None:
            out.insert(rng2[0] + 1, f"  was_on: {today}   # the old install was running this; set enabled: on to restore")
            lines = out

new_text = "\n".join(out).rstrip("\n") + "\n"
if new_text != text:
    target.write_text(new_text, encoding="utf-8")

print(f"0024-wardens-off-until-named: {target}")
for row in set_off:
    print(f"  off      {row}")
for row in kept:
    print(f"  kept     {row}")
if any(was_running.values()):
    print("  recorded was_on for: " + ", ".join(d for d, r in was_running.items() if r))


# ── stop and disable the clocks the old install seated ──────────────────────────────────────────
# A unit FILE is kept on purpose: the door is one edit and one `enable --now` away, and a migration that
# deleted it would be the deletion RULES/11 forbids.
off_doors = [door for door in UNITS if not any(row.startswith(door + ":") for row in kept)]
if all(value is None for value in was_running.values()):
    for door in off_doors:
        if UNITS[door]:
            print(f"  would-stop {UNITS[door]} (no systemd here to ask)")
    sys.exit(0)

for door in off_doors:
    unit = UNITS[door]
    if not unit or not was_running.get(door):
        continue
    systemctl("disable", "--now", unit)
    after = systemctl("is-active", unit)
    state = after.stdout.strip() if after is not None else "unknown"
    print(f"  stopped  {unit} (now {state or 'inactive'}; the unit file is kept, so naming the door restores it)")
PYTHON
rc=$?
[ "$rc" = 0 ] || { printf '0024-wardens-off-until-named: the recording failed (%s)\n' "$rc" >&2; exit 1; }

printf '0024-wardens-off-until-named: no outward warden runs on %s until a person names one in %s\n' "$MACHINE" "$FILE"
exit 0
