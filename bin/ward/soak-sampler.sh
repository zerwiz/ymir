#!/usr/bin/env bash
# soak-sampler.sh — the leak ledger: one row per house service and per Electron app, every five
# minutes, so a leak is a number in a file instead of a crash at midnight (plan 286 P0).
#
# WHAT IT RECORDS, per target, one JSON row per pass:
#   rss_kb · fds · fd_limit · inotify_watches · pids · zombies · gpu_mib · restarts · state
#
# WHAT IT NEVER DOES: it reads. No app is restarted, no unit is touched, nothing is raised or
# lowered here. The one hand in this family is `bin/ward/restart-storm.sh`, which this pass calls
# at its end (plan 286 P4) — and even that stops nothing while a call is held on the desk.
#
# DISCOVERY IS GENERIC, never a list of ours:
#   services — the units this machine has installed itself (a unit whose FragmentPath is the
#              distribution's is not the house's; `sample.include_vendor: true` takes them too).
#              Reported for every unit that is active, failed, restarting, or has restarted; a
#              dead one-shot from last week has nothing to measure and is left out.
#   apps     — the app registry (`bin/desktop/ymir-app --list`), and then the processes whose
#              command line names that app's directory. A registry that cannot be read is a ROW
#              that says so, never an empty ledger that looks quiet.
#
# WHERE THE ROWS GO:  $YMIR_HOME/state/soak/services/<YYYY-MM-DD>.jsonl   (one JSON line per row)
#   a `kind:"pass"` row closes every pass (targets, rows, seconds, tree) so the hour is provable;
#   `kind:"service"` and `kind:"app"` rows carry the numbers; `kind:"storm"` rows are the ward's.
#
# USAGE
#   soak-sampler.sh [pass] [--scope user|system|both] [--dry-run] [--no-ward] [--quiet]
#   soak-sampler.sh --install-timer [--tree PATH] [--interval MIN]
#   soak-sampler.sh --uninstall-timer
#   soak-sampler.sh --status [--json]
#   soak-sampler.sh --version
#
# THE TIMER is a USER timer (one per machine, no root): `ymir-soak.timer` → `ymir-soak.service`,
# every five minutes, which runs this file's `pass`. It is enabled by the machine's own holder,
# never by a worker on someone else's machine (RULES/41, RULES/55). `--install-timer` refuses to
# seat a unit whose ExecStart does not exist, and its default tree is the PIN, not a working tree
# (RULES/51).
#
# ENV (all optional; the ones marked test-* exist so this door can be proved without a real fault)
#   YMIR_SOAK_STATE        the state dir (default <home>/state/soak)
#   YMIR_SOAK_CONFIG       the config  (default <home>/config/soak.yaml)
#   YMIR_SOAK_SCOPE        user | system | both
#   YMIR_SOAK_APP_REGISTRY test: a file naming apps, one per line, instead of `ymir-app --list`
#   YMIR_SOAK_PROC         test: a fake /proc root
#   YMIR_SOAK_CGROUP       test: a fake /sys/fs/cgroup root
#   YMIR_SOAK_SYSTEMCTL    test: a stand-in systemctl
#   YMIR_NVIDIA_SMI        test: a stand-in nvidia-smi
#
# Exit: 0 the pass wrote its rows · 3 a pass ran and wrote nothing (the fault is named) · 2 usage.
set -uo pipefail

VERSION="1.0.0"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _w in "$SELF_DIR/../vault/hoard-lib.sh" "$ROOT/bin/vault/hoard-lib.sh"; do
    [ -r "$_w" ] && { . "$_w"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _w
fi
# The home and the state are RESOLVED, never guessed (Rule 07): hoard-lib owns both answers.
HOME_DIR=""; declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root HOME_DIR 2>/dev/null
if [ -z "$HOME_DIR" ]; then printf 'error: the home is unresolved (bin/vault/hoard-lib.sh)\n' >&2; exit 1; fi
STATE_BASE=""; declare -f hoard_state_dir >/dev/null 2>&1 && hoard_state_dir STATE_BASE 2>/dev/null
if [ -z "$STATE_BASE" ]; then printf 'error: the state dir is unresolved (bin/vault/hoard-lib.sh)\n' >&2; exit 1; fi
SOAK_STATE="${YMIR_SOAK_STATE:-$STATE_BASE/soak}"
CONFIG="${YMIR_SOAK_CONFIG:-$HOME_DIR/config/soak.yaml}"
LEDGER_DIR="$SOAK_STATE/services"
PIN="${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}"
SYSTEMCTL="${YMIR_SOAK_SYSTEMCTL:-systemctl}"

usage() { sed -n '2,50p' "$0" | sed 's/^# \{0,1\}//'; }
die() { printf 'error: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf 'help: %s\n' "$2" >&2; exit 2; }

# ── the config, read through the home (Rule 07: one place, one default) ───────────
# Reads `<home>/config/soak.yaml`. A key it cannot find falls back to the documented default and
# SAYS SO, so `--status` prints where each value came from. PyYAML when present, else a two-level
# `key: value` scan — this file's own shape, nothing clever.
cfg_get() {  # <dotted.key> <default> → "value<TAB>config|default"
  python3 - "$CONFIG" "$1" "$2" <<'PY' 2>/dev/null || printf '%s\tdefault\n' "$3"
import sys
path, dotted, default = sys.argv[1], sys.argv[2], sys.argv[3]
data = None
try:
    import yaml
    with open(path) as fh:
        data = yaml.safe_load(fh)
except Exception:
    data = None
if not isinstance(data, dict):
    data = {}
    try:
        section = None
        for raw in open(path):
            line = raw.split("#", 1)[0].rstrip()
            if not line.strip():
                continue
            if not line.startswith((" ", "\t")) and line.rstrip().endswith(":"):
                section = line.strip()[:-1]
                data.setdefault(section, {})
                continue
            if ":" in line:
                k, v = line.strip().split(":", 1)
                v = v.strip().strip('"').strip("'")
                if line.startswith((" ", "\t")) and section:
                    data[section][k] = v
                else:
                    data[k] = v
    except Exception:
        data = {}
cur = data
for part in dotted.split("."):
    if isinstance(cur, dict) and part in cur:
        cur = cur[part]
    else:
        print("%s\tdefault" % default)
        sys.exit(0)
if isinstance(cur, bool):
    cur = "true" if cur else "false"
if cur is None or cur == "":
    print("%s\tdefault" % default)
    sys.exit(0)
print("%s\tconfig" % cur)
PY
}
cfg_val() { cfg_get "$1" "$2" | cut -f1; }
cfg_src() { cfg_get "$1" "$2" | cut -f2; }

cmd_status() {
  local json=0
  [ "${1:-}" = "--json" ] && json=1
  local tmr="ymir-soak.timer" active="inactive" next="" rows=0 last="" today
  today="$(date +%F)"
  systemctl --user is-active "$tmr" 2>/dev/null | grep -q '^active' && active="active"
  next="$(systemctl --user list-timers "$tmr" --no-legend --no-pager 2>/dev/null | head -n 1 \
    | awk '{print $1" "$2" "$3" "$4}')"
  [ -f "$LEDGER_DIR/$today.jsonl" ] && rows="$(wc -l < "$LEDGER_DIR/$today.jsonl")"
  last="$(grep -h '"kind":"pass"' "$LEDGER_DIR"/*.jsonl 2>/dev/null | tail -n 1)"
  if [ "$json" = 1 ]; then
    printf '{"timer":"%s","active":"%s","next":"%s","rows_today":%s,"last_pass":%s}\n' \
      "$tmr" "$active" "${next//\"/}" "$rows" "${last:-null}"
    return 0
  fi
  local threshold wm scope enabled exclude
  threshold="$(cfg_val restart_storm.threshold 10)"; wm="$(cfg_val restart_storm.window_minutes 60)"
  scope="$(cfg_val restart_storm.scope user)"; enabled="$(cfg_val restart_storm.enabled true)"
  exclude="$(cfg_val restart_storm.exclude '')"
  printf 'timer,%s,%s\n' "$tmr" "$active"
  printf 'next,%s\n' "${next:-(not scheduled)}"
  printf 'ledger,%s\n' "$LEDGER_DIR/$today.jsonl"
  printf 'rows_today,%s\n' "$rows"
  printf 'sampled_scope,%s [%s]\n' "$(cfg_val sample.scope user)" "$(cfg_src sample.scope user)"
  printf 'ward,enabled=%s threshold=%s window=%s scope=%s [%s/%s/%s/%s]\n' \
    "$enabled" "$threshold" "$wm" "$scope" \
    "$(cfg_src restart_storm.enabled true)" "$(cfg_src restart_storm.threshold 10)" \
    "$(cfg_src restart_storm.window_minutes 60)" "$(cfg_src restart_storm.scope user)"
  [ -n "$exclude" ] && printf 'ward_exclude,%s\n' "$exclude"
  return 0
}

# ── the timer: one user timer, seated by the machine's own holder ────────────────
cmd_install_timer() {
  local tree="" interval="5"
  while [ $# -gt 0 ]; do
    case "$1" in
      --tree) tree="${2:-}"; shift 2 ;;
      --interval) interval="${2:-}"; shift 2 ;;
      *) die "unknown flag $1" "soak-sampler.sh --install-timer [--tree PATH] [--interval MIN]" ;;
    esac
  done
  if [ -z "$tree" ]; then
    # The PIN first (Rule 51: a root agent loads the pinned runtime, never a working tree), then
    # this file's own tree. Whichever answers is written into the unit and said out loud.
    if [ -x "$PIN/bin/ward/soak-sampler.sh" ]; then tree="$PIN"; else tree="$ROOT"; fi
  fi
  [ -x "$tree/bin/ward/soak-sampler.sh" ] || die "no soak-sampler.sh under $tree" "point --tree at a Ymir tree"
  case "$interval" in ''|*[!0-9]*) die "--interval must be minutes (a number)" ;; esac
  [ "$interval" -ge 1 ] || die "--interval must be at least 1"
  local u="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  mkdir -p "$u" || die "cannot write $u"
  cat > "$u/ymir-soak.service" <<UNIT
[Unit]
Description=ymir soak — the leak ledger (plan 286 P0) and the restart-storm ward (P4)
Documentation=file:$tree/bin/ward/soak-sampler.sh
# tree: $tree

[Service]
Type=oneshot
ExecStart=/usr/bin/env bash $tree/bin/ward/soak-sampler.sh pass --quiet
Nice=10
IOSchedulingClass=idle
TimeoutStartSec=240
UNIT
  cat > "$u/ymir-soak.timer" <<UNIT
[Unit]
Description=ymir soak — a row per service and app, every $interval minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=$interval min
AccuracySec=30s
Unit=ymir-soak.service

[Install]
WantedBy=timers.target
UNIT
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable --now ymir-soak.timer >/dev/null 2>&1 || true
  printf 'installed,ymir-soak.timer,tree=%s,every=%smin,active=%s\n' \
    "$tree" "$interval" "$(systemctl --user is-active ymir-soak.timer 2>/dev/null)"
}

cmd_uninstall_timer() {
  local u="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  systemctl --user disable --now ymir-soak.timer 2>/dev/null || true
  rm -f "$u/ymir-soak.timer" "$u/ymir-soak.service"
  systemctl --user daemon-reload 2>/dev/null || true
  printf 'uninstalled,ymir-soak.timer\n'
}

# ── discovery ────────────────────────────────────────────────────────────────────
# One systemctl call per scope for the names, then ONE `show` for every unit's properties: 120
# units cost 120 short calls otherwise, and a five-minute timer must not spend a minute of it.
collect_units() {  # <scope> → TSV rows (see the consumer below)
  local scope="$1"
  local -a flags=() names=() chunk=()
  case "$scope" in
    user) flags=(--user) ;;
    system) flags=(--system) ;;
    *) return 0 ;;
  esac
  local line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    names+=("${line%% *}")
  done < <("$SYSTEMCTL" "${flags[@]}" list-units --type=service --all --plain --no-legend --no-pager 2>/dev/null)
  [ "${#names[@]}" -gt 0 ] || return 0
  local i=0
  while [ "$i" -lt "${#names[@]}" ]; do
    chunk=("${names[@]:$i:100}")
    "$SYSTEMCTL" "${flags[@]}" show --no-pager \
      -p Id -p ActiveState -p SubState -p MainPID -p NRestarts -p ControlGroup -p Result \
      -p ExecMainStatus -p ExecMainStartTimestamp -p FragmentPath -p Restart "${chunk[@]}" 2>/dev/null
    i=$((i + 100))
  done | SCOPE="$scope" python3 -c '
import os, sys
scope = os.environ["SCOPE"]
blocks, cur = [], {}
for line in sys.stdin:
    line = line.rstrip("\n")
    if not line.strip():
        if cur: blocks.append(cur); cur = {}
        continue
    if "=" in line:
        k, v = line.split("=", 1); cur[k] = v
if cur: blocks.append(cur)
for b in blocks:
    if not b.get("Id"): continue
    print("\t".join([b.get("Id",""), scope, b.get("ActiveState",""), b.get("SubState",""),
                     b.get("MainPID","0"), b.get("NRestarts","0"), b.get("ControlGroup",""),
                     b.get("Result",""), b.get("ExecMainStatus","0"),
                     b.get("ExecMainStartTimestamp",""), b.get("FragmentPath",""),
                     b.get("Restart","")]))
'
}

collect_apps() {  # → TSV: name<TAB>package
  local name pkg reg listcmd=""
  reg="${YMIR_SOAK_APP_REGISTRY:-}"
  if [ -n "$reg" ]; then
    [ -r "$reg" ] || return 1
    while IFS= read -r name; do
      name="${name%%[[:space:]]*}"; [ -n "$name" ] || continue
      printf '%s\t%s\n' "$name" "$name"
    done < "$reg"
    return 0
  fi
  for _l in "$ROOT/bin/desktop/app-lib.sh" "$PIN/bin/desktop/app-lib.sh"; do
    [ -r "$_l" ] && { . "$_l"; break; }
  done
  if [ -x "$ROOT/bin/desktop/ymir-app" ]; then listcmd="$ROOT/bin/desktop/ymir-app"
  elif [ -x "$PIN/bin/desktop/ymir-app" ]; then listcmd="$PIN/bin/desktop/ymir-app"; fi
  [ -n "$listcmd" ] || return 1
  "$listcmd" --list 2>/dev/null | while IFS= read -r name; do
    name="${name%%[[:space:]]*}"; [ -n "$name" ] || continue
    pkg="$name"
    if declare -f app_pkg >/dev/null 2>&1; then pkg="$(app_pkg "$name")"; fi
    printf '%s\t%s\n' "$name" "$pkg"
  done
}

# ── the pass ────────────────────────────────────────────────────────────────────
cmd_pass() {
  local dry=0 ward=1 quiet=0 scope_arg=""
  while [ $# -gt 0 ]; do
    case "$1" in
      pass) ;;
      --dry-run) dry=1 ;;
      --no-ward) ward=0 ;;
      --quiet) quiet=1 ;;
      --scope) scope_arg="${2:-}"; shift ;;
      *) die "unknown flag $1" "soak-sampler.sh pass [--scope user|system|both] [--dry-run] [--no-ward]" ;;
    esac
    shift
  done
  local scope="${scope_arg:-${YMIR_SOAK_SCOPE:-$(cfg_val sample.scope user)}}"
  case "$scope" in user|system|both) ;; *) die "scope must be user|system|both (got '$scope')" ;; esac

  local ts pass host date t0 tmp units apps registry_ok=1
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  pass="$(date -u +%Y%m%dT%H%M%SZ)"
  host="$(hostname -s 2>/dev/null || echo unknown)"
  date="$(date +%F)"
  t0="$(date +%s)"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/ymir-soak.XXXXXX")" || { printf 'soak-sampler: no temp dir\n' >&2; return 3; }
  units="$tmp/units.tsv"; apps="$tmp/apps.tsv"
  : > "$units"; : > "$apps"
  case "$scope" in
    user) collect_units user >> "$units" ;;
    system) collect_units system >> "$units" ;;
    both) collect_units user >> "$units"; collect_units system >> "$units" ;;
  esac
  collect_apps > "$apps" || registry_ok=0

  local out="$tmp/rows.jsonl" rc=0
  YMIR_SOAK_PROC="${YMIR_SOAK_PROC:-/proc}" \
  YMIR_SOAK_CGROUP="${YMIR_SOAK_CGROUP:-/sys/fs/cgroup}" \
  YMIR_NVIDIA_SMI="${YMIR_NVIDIA_SMI:-nvidia-smi}" \
  SOAK_PASS="$pass" SOAK_TS="$ts" SOAK_HOST="$host" SOAK_SCOPE="$scope" \
  SOAK_STATE="$SOAK_STATE" SOAK_UNITS="$units" SOAK_APPS="$apps" \
  SOAK_REGISTRY_OK="$registry_ok" SOAK_INCLUDE_VENDOR="$(cfg_val sample.include_vendor false)" \
  SOAK_PIN="$PIN" SOAK_T0="$t0" SOAK_DRY="$dry" \
  python3 - > "$out" <<'PY' || rc=$?
import json, os, shutil, subprocess, time

proc = os.environ["YMIR_SOAK_PROC"].rstrip("/")
cgroot = os.environ["YMIR_SOAK_CGROUP"].rstrip("/")
state = os.environ["SOAK_STATE"]
ts = os.environ["SOAK_TS"]
pass_id = os.environ["SOAK_PASS"]
host = os.environ["SOAK_HOST"]
scope = os.environ["SOAK_SCOPE"]
include_vendor = os.environ.get("SOAK_INCLUDE_VENDOR", "false") == "true"
PAGE = os.sysconf("SC_PAGE_SIZE")

def rd(path, mode="r"):
    try:
        with open(path, mode) as fh:
            return fh.read()
    except Exception:
        return None

# One scan of the process table: identity, parent, state, start time, and the command lines of
# the processes an app may be.
procs, children, cmdlines = {}, {}, {}
children_seen = set()
for name in (os.listdir(proc) if os.path.isdir(proc) else []):
    if not name.isdigit():
        continue
    raw = rd("%s/%s/stat" % (proc, name))
    if not raw:
        continue
    rp = raw.rfind(")")
    if rp < 0:
        continue
    rest = raw[rp + 2:].split()
    if len(rest) < 20:
        continue
    pid = int(name)
    procs[pid] = {"ppid": int(rest[1]), "state": rest[0], "start": rest[19]}
    children.setdefault(int(rest[1]), []).append(pid)

def descendants(pid, seen=None):
    seen = set() if seen is None else seen
    for child in children.get(pid, []):
        if child in seen:
            continue
        seen.add(child)
        descendants(child, seen)
    return seen

def cmdline(pid):
    if pid not in cmdlines:
        raw = rd("%s/%d/cmdline" % (proc, pid), "rb")
        cmdlines[pid] = raw.replace(b"\x00", b" ").decode("utf-8", "replace") if raw else ""
    return cmdlines[pid]

def cgroup_pids(cg):
    if not cg:
        return []
    out = rd("%s%s/cgroup.procs" % (cgroot, cg))
    if not out:
        return []
    return [int(x) for x in out.split() if x.isdigit()]

def rss_kb(pid):
    status = rd("%s/%d/status" % (proc, pid))
    if status:
        for line in status.splitlines():
            if line.startswith("VmRSS:"):
                try:
                    return int(line.split()[1])
                except (IndexError, ValueError):
                    pass
    statm = rd("%s/%d/statm" % (proc, pid))
    if statm:
        try:
            return int(statm.split()[1]) * PAGE // 1024
        except (IndexError, ValueError):
            pass
    return 0

def fds(pid):
    try:
        return len(os.listdir("%s/%d/fd" % (proc, pid)))
    except Exception:
        return 0

def fd_limit(pid):
    limits = rd("%s/%d/limits" % (proc, pid))
    if not limits:
        return None
    for line in limits.splitlines():
        if line.startswith("Max open files"):
            parts = line.split()
            try:
                v = int(parts[3])
                return "unlimited" if v >= (1 << 62) else v
            except (IndexError, ValueError):
                return None
    return None

def inotify_watches(pid):
    d = "%s/%d/fdinfo" % (proc, pid)
    try:
        names = os.listdir(d)
    except Exception:
        return 0
    n = 0
    for fn in names:
        body = rd("%s/%s" % (d, fn))
        if not body:
            continue
        n += sum(1 for line in body.splitlines() if line.startswith("inotify wd:"))
    return n

# The GPU's memory belongs to the process holding the context, which is usually a child.
gpu, gpu_ok = {}, False
tool = os.environ.get("YMIR_NVIDIA_SMI") or "nvidia-smi"
have = (os.access(tool, os.X_OK) if os.path.sep in tool else shutil.which(tool) is not None)
if have:
    try:
        out = subprocess.run([tool, "--query-compute-apps=pid,used_memory", "--format=csv,noheader,nounits"],
                             capture_output=True, text=True, timeout=10).stdout
        for line in out.splitlines():
            bits = [b.strip() for b in line.split(",")]
            if len(bits) >= 2 and bits[0].isdigit():
                try:
                    gpu[int(bits[0])] = int(float(bits[1]))
                except ValueError:
                    pass
        gpu_ok = True
    except Exception:
        gpu_ok = False

def measure(pids):
    pids = [p for p in pids if p in procs]
    return {
        "pids": len(pids),
        "rss_kb": sum(rss_kb(p) for p in pids),
        "fds": sum(fds(p) for p in pids),
        "fd_limit": fd_limit(pids[0]) if pids else None,
        "inotify_watches": sum(inotify_watches(p) for p in pids),
        "zombies": sum(1 for p in pids if procs[p]["state"] == "Z"),
        "gpu_mib": (sum(gpu.get(p, 0) for p in pids) if gpu_ok else None),
    }

def vendor_unit(fragment):
    return fragment.startswith(("/usr/lib/systemd/", "/lib/systemd/", "/usr/share/systemd/"))

rows, targets, units_seen = [], 0, 0
with open(os.environ["SOAK_UNITS"]) as fh:
    for line in fh:
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 12:
            continue
        (uid, uscope, active, sub, main_pid, restarts, cg, result, exec_status,
         started, fragment, restart) = parts[:12]
        if vendor_unit(fragment) and not include_vendor:
            continue
        try:
            main_pid = int(main_pid or 0)
            restarts = int(restarts or 0)
        except ValueError:
            continue
        if active not in ("active", "activating", "deactivating", "reloading", "failed") \
           and restarts == 0 and sub not in ("auto-restart", "start"):
            continue
        pids = cgroup_pids(cg) if cg else []
        if not pids and main_pid:
            pids = [main_pid] + sorted(descendants(main_pid))
        # A finished one-shot (active/exited, no process) has nothing to measure; a failed unit
        # and one systemd is about to restart DO, whatever its pid says.
        if not pids and active != "failed" and sub not in ("auto-restart", "start") and restarts == 0:
            continue
        units_seen += 1
        m = measure(pids)
        row = {"ts": ts, "pass": pass_id, "host": host, "kind": "service",
               "scope": uscope, "name": uid, "state": active, "sub": sub,
               "main_pid": main_pid, "restarts": restarts, "started": started,
               "result": result, "exec_status": exec_status, "restart_policy": restart}
        row.update(m)
        rows.append(row)
        targets += 1

apps_state_path = os.path.join(state, "app-generations.json")
try:
    apps_state = json.load(open(apps_state_path))
    if not isinstance(apps_state, dict):
        apps_state = {}
except Exception:
    apps_state = {}
apps_changed = False
app_names = []
with open(os.environ["SOAK_APPS"]) as fh:
    for line in fh:
        bits = line.rstrip("\n").split("\t")
        if bits and bits[0]:
            app_names.append((bits[0], bits[1] if len(bits) > 1 else bits[0]))

for name, pkg in app_names:
    pats = ["/apps/%s/" % name, "/apps/%s/" % pkg, "/node_modules/@zerwiz/%s/" % pkg]
    matched = [pid for pid in procs if any(p in cmdline(pid) for p in pats)]
    prev = apps_state.get(name) or {}
    gen = int(prev.get("generation", 0) or 0)
    if not matched:
        rows.append({"ts": ts, "pass": pass_id, "host": host, "kind": "app", "scope": "app",
                     "name": name, "state": "absent", "sub": "not-running", "main_pid": 0,
                     "restarts": gen, "generation": gen, "started": "",
                     "pids": 0, "rss_kb": 0, "fds": 0, "fd_limit": None,
                     "inotify_watches": 0, "zombies": 0, "gpu_mib": 0})
        targets += 1
        continue
    roots = sorted(p for p in matched if procs[p]["ppid"] not in matched) or sorted(matched)
    pids = set(roots)
    for r in roots:
        pids |= descendants(r)
    main_pid = roots[0]
    identity = [main_pid, procs[main_pid]["start"]]
    if prev and (prev.get("main_pid") != identity[0] or str(prev.get("start")) != str(identity[1])):
        # The main process changed: the app started again. Its renderers and GPU memory reset
        # with it, so the generation is the restart count a person means by "it crashed again".
        gen += 1
    apps_state[name] = {"main_pid": identity[0], "start": identity[1],
                        "generation": gen, "last_seen": ts}
    apps_changed = True
    m = measure(sorted(pids))
    row = {"ts": ts, "pass": pass_id, "host": host, "kind": "app", "scope": "app",
           "name": name, "state": "running", "sub": "running", "main_pid": main_pid,
           "restarts": gen, "generation": gen, "started": ""}
    row.update(m)
    rows.append(row)
    targets += 1

if apps_changed and os.environ.get("SOAK_DRY") != "1":
    try:
        os.makedirs(state, exist_ok=True)
        tmp = apps_state_path + ".tmp"
        with open(tmp, "w") as fh:
            json.dump(apps_state, fh, indent=1, sort_keys=True)
        os.replace(tmp, apps_state_path)
    except Exception:
        pass

if os.environ.get("SOAK_REGISTRY_OK") == "0":
    rows.append({"ts": ts, "pass": pass_id, "host": host, "kind": "discovery",
                 "name": "app-registry", "state": "unreadable",
                 "detail": "the app registry answered nothing: the app rows are missing, not zero"})

rows.append({"ts": ts, "pass": pass_id, "host": host, "kind": "pass", "scope": scope,
             "targets": targets, "units_seen": units_seen, "apps": len(app_names),
             "seconds": max(0, int(time.time()) - int(os.environ.get("SOAK_T0", "0"))),
             "gpu_source": ("nvidia-smi" if gpu_ok else "none"),
             "tree": os.environ.get("SOAK_PIN", "")})
for row in rows:
    print(json.dumps(row, separators=(",", ":")))
PY

  if [ "$rc" -ne 0 ] || [ ! -s "$out" ]; then
    printf 'soak-sampler: the collector wrote nothing (exit %s)\n' "$rc" >&2
    rm -rf "$tmp"; return 3
  fi
  local wrote=0
  if [ "$dry" = 0 ]; then
    if ! mkdir -p "$LEDGER_DIR"; then
      printf 'soak-sampler: cannot write %s\n' "$LEDGER_DIR" >&2
      rm -rf "$tmp"; return 3
    fi
    cat "$out" >> "$LEDGER_DIR/$date.jsonl"
    wrote=1
    [ "$quiet" = 1 ] || printf 'soak,%s,rows=%s,ledger=%s\n' "$pass" "$(wc -l < "$out")" "$LEDGER_DIR/$date.jsonl"
  else
    cat "$out"
  fi
  rm -rf "$tmp"

  if [ "$ward" = 1 ]; then
    local ward_bin=""
    if [ -x "$ROOT/bin/ward/restart-storm.sh" ]; then ward_bin="$ROOT/bin/ward/restart-storm.sh"
    elif [ -x "$PIN/bin/ward/restart-storm.sh" ]; then ward_bin="$PIN/bin/ward/restart-storm.sh"; fi
    if [ -n "$ward_bin" ]; then
      local wargs=(--pass --scope "$scope" --quiet)
      [ "$dry" = 1 ] && wargs=(--pass --scope "$scope" --dry-run --quiet)
      "$ward_bin" "${wargs[@]}" || true
    else
      printf 'soak-sampler: the storm ward is not beside me; the rows are the ledger only\n' >&2
    fi
  fi
  [ "$wrote" = 1 ] || [ "$dry" = 1 ] || return 3
  return 0
}

case "${1:-pass}" in
  pass|"") shift || true; cmd_pass "$@" ;;
  --install-timer|install-timer) shift; cmd_install_timer "$@" ;;
  --uninstall-timer|uninstall-timer) cmd_uninstall_timer ;;
  --status|status) shift || true; cmd_status "$@" ;;
  -v|--version) printf '%s\n' "$VERSION" ;;
  -h|--help|help) usage ;;
  *) die "unknown action $1" "soak-sampler.sh [pass|--install-timer|--uninstall-timer|--status]" ;;
esac
