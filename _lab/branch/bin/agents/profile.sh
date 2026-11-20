#!/usr/bin/env bash
# profile.sh — what THIS user's machine actually is, probed not assumed.
#
# Every deployment differs: hardware, OS, GPU, tools, fleet role, seat name. This
# door writes one machine-readable profile that install, update and features read
# instead of guessing. Missing capability is recorded as absent, never inferred.
#
#   profile.sh probe     # probe and write <home>/hodd/identity/profile.yaml
#   profile.sh show      # print the profile (TOON)
#   profile.sh check     # exit 1 when the profile is absent or stale
#
# Exit: 0 ok · 1 absent/stale · 2 usage
set -euo pipefail
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1-}"; shift || true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$ROOT/bin/vault/hoard-lib.sh"; do [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }; done; unset _c
fi
ymir_home_root YMIR_HOME 2>/dev/null || true
YMIR_HOME="${YMIR_HOME:?YMIR_HOME unresolved}"
OUT="$YMIR_HOME/hodd/identity/profile.yaml"
mkdir -p "$(dirname "$OUT")"

probe() {
  python3 - "$ROOT" "$YMIR_HOME" "$OUT" <<'PY'
import sys, os, json, shutil, subprocess, socket, platform, datetime
root, home, out = sys.argv[1:4]
def have(c): return shutil.which(c) is not None
def run(cmd):
    try: return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception: return ""
def mem_gb():
    try:
        for l in open('/proc/meminfo'):
            if l.startswith('MemTotal:'): return round(int(l.split()[1])/1048576)
    except Exception: pass
    return None
def gpu():
    if not have('nvidia-smi'): return None
    out = run("nvidia-smi --query-gpu=name,memory.total --format=csv,noheader")
    return out or None
def disk():
    try: return shutil.disk_usage(home).free // (1024**3)
    except Exception: return None
prof = {
  "version": 1,
  "generated": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
  "host": socket.gethostname(),
  "os": platform.system().lower(),
  "distro": (platform.freedesktop_os_release().get("PRETTY_NAME") if hasattr(platform,"freedesktop_os_release") else ""),
  "arch": platform.machine(),
  "cpu": platform.processor() or run("uname -p"),
  "cores": os.cpu_count(),
  "ram_gb": mem_gb(),
  "gpu": gpu(),
  "free_disk_gb": disk(),
  "software": {c: have(c) for c in ["git","docker","node","pi","tailscale","ffmpeg","whisper-cli","uv","python3","age"]},
  "home": home,
  "features": {
    "containers": have("docker"),
    "gpu_cuda": bool(gpu()),
    "tailnet": have("tailscale") and run("tailscale status --json >/dev/null 2>&1; echo $?") == "0",
    "meeting_ear": have("whisper-cli") or os.path.exists(os.path.expanduser("~/whisper.cpp")),
  },
}
try:
    import yaml
    yaml.safe_dump(prof, open(out,"w"), sort_keys=True)
except Exception:
    json.dump(prof, open(out,"w"), indent=2)
print(f"probed\t{out}\thost:{prof['host']}\tos:{prof['os']}\tgpu:{'yes' if prof['gpu'] else 'no'}")
PY
}

case "$ACTION" in
  probe) probe ;;
  show) [ -r "$OUT" ] || { printf 'error: no profile — run: profile.sh probe\n' >&2; exit 1; }
        python3 - "$OUT" <<'PY'
import sys,yaml,json
p=sys.argv[1]
d=yaml.safe_load(open(p))
print(f"profile{{host,os,arch,cores,ram_gb,gpu,free_disk_gb}}:")
print(f'  "{d.get("host")}","{d.get("os")}","{d.get("arch")}",{d.get("cores")},{d.get("ram_gb")},"{(d.get("gpu") or "").replace(chr(10)," / ")}",{d.get("free_disk_gb")}')
for k,v in (d.get("software") or {}).items(): print(f"  software/{k}: {'yes' if v else 'no'}")
for k,v in (d.get("features") or {}).items(): print(f"  feature/{k}: {'yes' if v else 'no'}")
PY
        ;;
  check) [ -r "$OUT" ] || { printf 'missing\t%s\n' "$OUT"; exit 1; }
        age=$(( $(date +%s) - $(stat -c %Y "$OUT") ))
        [ "$age" -lt 86400 ] && printf 'fresh\t%s\n' "$OUT" || { printf 'stale\t%s\tage:%ss\n' "$OUT" "$age"; exit 1; } ;;
  *) printf 'usage: profile.sh probe|show|check\n' >&2; exit 2 ;;
esac
