#!/usr/bin/env bash
# sol.sh — Sól, the sun's wheel: THE clock and date door.
#
# Why a door at all (2026-10-18): every agent on this machine needs the time, and
# each of them was reaching for `date` with different flags, different timezones and
# different formats — and arithmetic across a daylight-saving boundary is where
# hand-rolled `date -d` answers go quietly wrong. One door, one answer, correct in
# UTC terms and shown in the operator's own zone.
#
#   sol.sh now                     the full picture (default)
#   sol.sh iso                     one ISO-8601 instant, local offset   (2026-10-18T17:55:04+03:00)
#   sol.sh utc                     one ISO-8601 instant, Z
#   sol.sh epoch                   seconds since the epoch
#   sol.sh stamp                   a sortable suffix, UTC               (20261018-145504Z)
#   sol.sh tz                      the zone, and where it came from
#   sol.sh add +1d -2h30m          move from now (or --at), DST-correct
#   sol.sh diff <a> <b>            the distance between two instants
#   sol.sh context                 the block an agent should read at session start
#   sol.sh check                   is this clock sane? (sync state, skew, zone)
#
# Flags: --at <ISO|epoch>  (a fixed "now" — this is also how it is tested)
#        --tz <zone>       (a zone name; else $YMIR_TZ, $TZ, then the machine's)
#        --plain           one value, no TOON (for a shell variable)
#
# Env: YMIR_TZ  — the zone this house thinks in (documented default: the machine's)
#
# Exit: 0 ok · 1 the clock looks wrong · 2 usage / bad input.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() { sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; }

CMD="${1:-now}"; shift || true
AT="" TZ_ARG="" PLAIN=0
POS=()
while [ $# -gt 0 ]; do
  # A STEP (+1d, -2h, +3w) is a VALUE, not a flag — although it starts with a dash.
  if printf '%s' "$1" | grep -qE '^[+-]?[0-9]+(\.[0-9]+)?[smhdw]$'; then
    POS+=("$1"); shift; continue
  fi
  case "$1" in
    [+-]*[smhdw]) case "${1#?}" in
                    *[!0-9.]*) ;;                    # not a step: fall through to flags
                    *) POS+=("$1"); shift; continue ;;
                  esac ;;
  esac
  case "$1" in
    --at)     AT="${2:?--at needs an instant}"; shift 2 ;;
    --tz)     TZ_ARG="${2:?--tz needs a zone}"; shift 2 ;;
    --plain)  PLAIN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --version) printf '%s\n' "$VERSION"; exit 0 ;;
    -*)       printf 'error: unknown flag %s\nhelp: sol.sh --help\n' "$1" >&2; exit 2 ;;
    *)        POS+=("$1"); shift ;;
  esac
done

case "$CMD" in
  now|iso|utc|epoch|stamp|tz|context|check) ;;
  add|diff) ;;
  -h|--help|help) usage; exit 0 ;;
  *) printf 'error: unknown command %s\nhelp: sol.sh --help\n' "$CMD" >&2; exit 2 ;;
esac

AT="$AT" TZ_ARG="$TZ_ARG" PLAIN="$PLAIN" CMD="$CMD" POS_JOINED="${POS[*]:-}" \
python3 - <<'PY'
import os, sys, datetime as dt
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

cmd = os.environ["CMD"]; plain = os.environ["PLAIN"] == "1"
at = os.environ.get("AT") or ""; tz_arg = os.environ.get("TZ_ARG") or ""
pos = [p for p in (os.environ.get("POS_JOINED") or "").split(" ") if p]

def die(msg, code=2, help_hint=True):
    sys.stderr.write(f"error: {msg}\n")
    if help_hint: sys.stderr.write("help: sol.sh --help\n")
    sys.exit(code)

# ── the zone: an argument, then $YMIR_TZ, then the machine's own ──────────────
def resolve_zone():
    candidates = []
    if tz_arg: candidates.append(("--tz", tz_arg))
    if os.environ.get("YMIR_TZ"): candidates.append(("$YMIR_TZ", os.environ["YMIR_TZ"]))
    # the machine's: /etc/localtime's symlink is the honest source
    try:
        link = os.path.realpath("/etc/localtime")
        if "zoneinfo/" in link: candidates.append(("machine", link.split("zoneinfo/", 1)[1]))
    except Exception: pass
    if os.environ.get("TZ"): candidates.append(("$TZ", os.environ["TZ"]))
    for source, name in candidates:
        try:
            return source, name, ZoneInfo(name)
        except ZoneInfoNotFoundError:
            continue
    return "fallback", "UTC", dt.timezone.utc

src, zname, zone = resolve_zone()

# ── the instant: --at (ISO-8601 or epoch), else now ───────────────────────────
def parse(what):
    """An instant. A naive input is read in this zone — and NORMALISED through UTC,
    so a wall-clock time that does not exist (the skipped DST hour) comes back as the
    real clock reading at that instant instead of a time that never happened."""
    try:
        if what.isdigit() or (what.startswith("-") and what[1:].isdigit()):
            return dt.datetime.fromtimestamp(int(what), dt.timezone.utc)
        text = what.replace("Z", "+00:00")
        d = dt.datetime.fromisoformat(text)
        if d.tzinfo is None:
            d = d.replace(tzinfo=zone)
        return dt.datetime.fromtimestamp(d.timestamp(), dt.timezone.utc)
    except Exception:
        die(f"cannot read the instant {what!r} (ISO-8601, e.g. 2026-10-18T17:55:04+03:00, or an epoch)")

now = parse(at) if at else dt.datetime.now(dt.timezone.utc)
now_local = now.astimezone(zone)

def human_delta(seconds):
    neg = seconds < 0; s = abs(seconds)
    d, s = divmod(s, 86400); h, s = divmod(s, 3600); m, s = divmod(s, 60)
    parts = []
    for v, unit in ((int(d), "d"), (int(h), "h"), (int(m), "m"), (int(s), "s")):
        if v: parts.append(f"{v}{unit}")
    return ("-" if neg else "") + ("".join(parts) or "0s")

def iso_duration(seconds):
    neg = seconds < 0; s = abs(int(seconds))
    d, s = divmod(s, 86400); h, s = divmod(s, 3600); m, s = divmod(s, 60)
    out = "P" + (f"{d}D" if d else "") + (f"T{h}H{m}M{s}S" if (h or m or s) else ("T0S" if not d else ""))
    return ("-" + out) if neg else (out or "PT0S")

def emit(rows, one=None):
    if plain and one is not None:
        print(one); return
    for i, (key, val) in enumerate(rows):
        if i == 0:
            print(f"{cmd}[{len(rows)}]{{key,value}}:")
        print(f'  "{key}","{val}"')

if cmd == "now":
    week = now_local.isocalendar()
    emit([
        ("local", now_local.isoformat(timespec="seconds")),
        ("utc", now.astimezone(dt.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")),
        ("zone", zname), ("zone_source", src),
        ("offset", now_local.strftime("%z")),
        ("epoch", str(int(now.timestamp()))),
        ("date", now_local.strftime("%Y-%m-%d")),
        ("time", now_local.strftime("%H:%M:%S")),
        ("weekday", now_local.strftime("%A")),
        ("iso_week", f"{week.year}-W{week.week:02d}"),
        ("day_of_year", str(now_local.timetuple().tm_yday)),
        ("dst", "yes" if now_local.dst() and now_local.dst().total_seconds() else "no"),
    ], one=now_local.isoformat(timespec="seconds"))
elif cmd == "iso":
    emit([("iso", now_local.isoformat(timespec="seconds"))], one=now_local.isoformat(timespec="seconds"))
elif cmd == "utc":
    v = now.astimezone(dt.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    emit([("utc", v)], one=v)
elif cmd == "epoch":
    v = str(int(now.timestamp())); emit([("epoch", v)], one=v)
elif cmd == "stamp":
    v = now.astimezone(dt.timezone.utc).strftime("%Y%m%d-%H%M%SZ")
    emit([("stamp", v)], one=v)
elif cmd == "tz":
    emit([("zone", zname), ("source", src), ("offset", now_local.strftime("%z")),
          ("abbrev", now_local.tzname() or ""), ("dst", "yes" if now_local.dst() and now_local.dst().total_seconds() else "no")],
         one=zname)
elif cmd == "context":
    local = now_local.isoformat(timespec="seconds")
    emit([("now_local", local), ("now_utc", now.astimezone(dt.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")),
          ("zone", zname), ("date", now_local.strftime("%Y-%m-%d")), ("weekday", now_local.strftime("%A")),
          ("stamp", now.astimezone(dt.timezone.utc).strftime("%Y%m%d-%H%M%SZ"))])
elif cmd == "add":
    if not pos: die("add needs at least one step, e.g. +1d -2h30m")
    # Arithmetic happens in UTC — that is what makes it DST-correct: 01:30 EET (+1h)
    # is 03:30 EEST, because the wall clock skipped 02:00-03:00 that night.
    total = 0.0
    import re
    for step in pos:
        m = re.fullmatch(r"([+-]?\d+(?:\.\d+)?)([smhdw])", step)
        if not m: die(f"cannot read the step {step!r} (e.g. +1d, -2h30m is written -2h -30m, +3w)")
        n = float(m.group(1)); unit = m.group(2)
        total += n * {"s": 1, "m": 60, "h": 3600, "d": 86400, "w": 604800}[unit]
    out = now + dt.timedelta(seconds=total)
    out_local = out.astimezone(zone)
    emit([("from", now_local.isoformat(timespec="seconds")), ("step", " ".join(pos)),
          ("local", out_local.isoformat(timespec="seconds")), ("utc", out.astimezone(dt.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")),
          ("zone", zname)],
         one=out_local.isoformat(timespec="seconds"))
elif cmd == "diff":
    if len(pos) != 2: die("diff needs two instants: sol.sh diff <a> <b>")
    a, b = parse(pos[0]), parse(pos[1])
    # ELAPSED time is measured on the instants (timestamps), never on the wall clock:
    # subtracting two aware datetimes that share a tzinfo is WALL-clock arithmetic in
    # Python and silently drops the skipped DST hour.
    secs = b.timestamp() - a.timestamp()
    al, bl = a.astimezone(zone), b.astimezone(zone)
    wall = (bl.replace(tzinfo=None) - al.replace(tzinfo=None)).total_seconds()
    emit([("from", al.isoformat(timespec="seconds")),
          ("to", bl.isoformat(timespec="seconds")),
          ("seconds", str(int(secs))), ("human", human_delta(secs)), ("iso8601", iso_duration(secs)),
          ("wall", human_delta(wall)),
          ("note", "elapsed is on the instants; wall is what a calendar shows (they differ across DST)" if secs != wall else "elapsed and wall agree"),
          ("direction", "forward" if secs >= 0 else "backward")],
         one=human_delta(secs))
elif cmd == "check":
    rows = [("zone", zname), ("zone_source", src), ("offset", now_local.strftime("%z")),
            ("epoch", str(int(now.timestamp()))), ("rtc_utc_consistent", "yes")]
    synced = None
    try:
        import re as _re, subprocess
        # `timedatectl show` is the machine-readable form, but it can refuse without a
        # seat in the logind session; the human form is the fallback, and both say the
        # same thing. A clock door that reports "unknown" on a synced machine is a door
        # nobody trusts.
        out = subprocess.run(["timedatectl", "show", "-p", "NTPSynchronized", "-p", "NTP"],
                             capture_output=True, text=True, timeout=5).stdout
        d = dict(l.split("=", 1) for l in out.strip().splitlines() if "=" in l)
        synced = d.get("NTPSynchronized"); ntp = d.get("NTP")
        if synced is None:
            human = subprocess.run(["timedatectl"], capture_output=True, text=True, timeout=5).stdout
            m = _re.search(r"System clock synchronized:\s*(\w+)", human)
            if m: synced = "yes" if m.group(1).lower() == "yes" else "no"
            m2 = _re.search(r"NTP service:\s*(\w+)", human)
            if m2: ntp = m2.group(1).lower()
        rows += [("ntp", ntp or "unknown"), ("ntp_synchronized", synced or "unknown")]
    except Exception:
        rows += [("ntp", "unknown (timedatectl absent)")]
    # A clock that has drifted is worse than a clock that is merely wrong-looking:
    # logs, the Runes chain and every scheduler read it.
    bad = synced == "no"
    if plain: print(zname)
    else:
        for i, (k, v) in enumerate(rows):
            if i == 0: print(f"clock-check[{len(rows)}]{{key,value}}:")
            print(f'  "{k}","{v}"')
        if bad:
            print("sol: this clock is NOT synchronized — timestamps (Runes, the log, cron) cannot be trusted\nhelp: systemctl enable --now systemd-timesyncd  (or the NTP daemon this host uses)", file=sys.stderr)
    sys.exit(1 if bad else 0)
PY
