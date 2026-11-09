#!/usr/bin/env bash
# arm-talk.sh — the heart speaks into every seat's pane, over that seat's own road (plan 234 P1).
set -uo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF/../.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
[ -n "${YMIR_HOME:-}" ] || ymir_home_root YMIR_HOME 2>/dev/null || true
[ -n "${YMIR_HOME:-}" ] || { printf 'arm-talk: home unresolved\n' >&2; exit 2; }
REG="$YMIR_HOME/hodd/data/fleet.json"

# --- arg parse ---
host=""
line=""
dry=0
mode=""
args=("$@")
i=0
while [ $i -lt ${#args[@]} ]; do
  a="${args[$i]}"
  case "$a" in
    --dry|--dry-run) dry=1; i=$((i+1)) ;;
    --) i=$((i+1)); line="${args[*]:$i}"; break ;;
    status|check) mode="$a"; i=$((i+1)) ;;
    *) if [ -z "$host" ]; then host="$a"; else line="${line:+$line }$a"; fi; i=$((i+1)) ;;
  esac
done

py() { python3 - "$REG" "$@"; }

road_of() { # prints tailnet user on two lines? instead use python to fetch
  python3 - "$REG" "$1" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); h=d.get("hosts",{}).get(sys.argv[2],{})
print(h.get("tailnet","")); print(h.get("user",""))
PY
}

is_heart() {
  [ "$1" = "local" ] && return 0
  hn="$(hostname)"
  [ "$1" = "$hn" ] && return 0
  # also heart role
  python3 - "$REG" "$1" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); h=d.get("hosts",{}).get(sys.argv[2],{})
print("yes" if "heart" in h.get("roles",[]) else "no")
PY
  [ "$(python3 - "$REG" "$1" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); h=d.get("hosts",{}).get(sys.argv[2],{})
print("yes" if "heart" in h.get("roles",[]) else "no")
PY
)" = "yes" ] 2>/dev/null
}

ssh_opts=(-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes)

# --- status ---
if [ "$mode" = "status" ]; then
  python3 - "$REG" <<'PY'
import json,subprocess,os
d=json.load(open(os.environ.get("REG","")))
hosts=d.get("hosts",{})
heart=d.get("heart")
for name,h in hosts.items():
    roles=",".join(h.get("roles",[]))
    tn=h.get("tailnet"); user=h.get("user")
    if not tn or not user:
        print(f"{name}: role={roles} road=NONE")
        continue
    if name==heart or name==subprocess.run(["hostname"],capture_output=True,text=True).stdout.strip():
        print(f"{name}: role={roles} road=local sha=? arm=?")
        continue
    try:
        r=subprocess.run(["ssh","-o","StrictHostKeyChecking=no","-o","ConnectTimeout=5","-o","BatchMode=yes",f"{user}@{tn}","cd ~/ymir && git rev-parse --short HEAD 2>/dev/null; bin/agents/eindri-notify.sh --status 2>&1"],capture_output=True,text=True,timeout=15)
        sha=r.stdout.strip().splitlines()[0] if r.stdout.strip() else "?"
        arm="?"
        for ln in r.stdout.splitlines():
            if "NOT FOUND" in ln or "no lock" in ln: arm="no-pane"
            if "pane" in ln.lower(): arm="resolved"
        print(f"{name}: role={roles} road={tn} sha={sha} arm={arm}")
    except Exception:
        print(f"{name}: role={roles} road={tn} DARK")
PY
  exit 0
fi

# --- check ---
if [ "$mode" = "check" ]; then
  python3 - "$REG" <<'PY'
import json,subprocess,os,datetime
d=json.load(open(os.environ.get("REG","")))
hosts=d.get("hosts",{})
heart=d.get("heart")
localhn=subprocess.run(["hostname"],capture_output=True,text=True).stdout.strip()
for name,h in hosts.items():
    tn=h.get("tailnet"); user=h.get("user")
    if not tn or not user:
        print(f"{name}: no road")
        continue
    if name==heart or name==localhn:
        print(f"{name}: up (local)")
        continue
    try:
        r=subprocess.run(["ssh","-o","StrictHostKeyChecking=no","-o","ConnectTimeout=5","-o","BatchMode=yes",f"{user}@{tn}","hostname"],capture_output=True,text=True,timeout=10)
        out=r.stdout.strip()
        if r.returncode==0 and out:
            print(f"{name}: up (tailnet) {out}")
        else:
            print(f"{name}: DARK (last seen unknown)")
    except Exception:
        print(f"{name}: DARK (last seen unknown)")
PY
  exit 0
fi

# --- delivery / dry-run ---
if [ -z "$host" ]; then
  printf 'usage: arm-talk.sh <host|local> -- "<line>"\n       arm-talk.sh status\n       arm-talk.sh check\n       arm-talk.sh <host> --dry-run -- "<line>"\n' >&2
  exit 2
fi

# resolve road
read -r tailnet user < <(road_of "$host" | tr '\n' ' ')
# road_of prints two lines; handle
tailnet="$(python3 - "$REG" "$host" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); h=d.get("hosts",{}).get(sys.argv[2],{})
print(h.get("tailnet",""))
PY
)"
user="$(python3 - "$REG" "$host" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); h=d.get("hosts",{}).get(sys.argv[2],{})
print(h.get("user",""))
PY
)"

if [ -z "$tailnet" ] || [ -z "$user" ]; then
  printf 'arm-talk: refused — no road named for %s (tailnet/user missing in fleet.json)\n' "$host" >&2
  exit 1
fi

# local/heart path
local_host=0
if [ "$host" = "local" ] || [ "$host" = "$(hostname)" ]; then local_host=1
fi
heart="$(python3 - "$REG" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); print(d.get("heart",""))
PY
)"
[ "$host" = "$heart" ] && local_host=1

escaped_line="$(printf '%q' "$line")"
remote_cmd="cd ~/ymir && bin/agents/eindri-notify.sh --from arm-talk -- $escaped_line"

if [ "$dry" = 1 ]; then
  if [ "$local_host" = 1 ]; then
    printf 'dry-run[1]{host,target,command}:\n  "%s","local","%s"\n' "$host" "$remote_cmd"
  else
    printf 'dry-run[1]{host,target,command}:\n  "%s","%s@%s","%s"\n' "$host" "$user" "$tailnet" "ssh ${ssh_opts[*]} $user@$tailnet \"$remote_cmd\""
  fi
  exit 0
fi

if [ -z "$line" ]; then
  printf 'usage: arm-talk.sh %s -- "<line>"\n' "$host" >&2
  exit 2
fi

if [ "$local_host" = 1 ]; then
  out="$(cd "$ROOT" && bash bin/agents/eindri-notify.sh --from arm-talk -- "$line" 2>&1)"
  rc=$?
else
  out="$(ssh "${ssh_opts[@]}" "$user@$tailnet" "$remote_cmd" 2>&1)"
  rc=$?
fi

if [ $rc -eq 0 ]; then
  pane="$(printf '%s\n' "$out" | sed -n 's/.*"\([^"]*\)".*/\1/p' | sed -n '2p')"
  # fallback parse: injected row second quoted field
  pane="$(printf '%s\n' "$out" | grep -o '"[^"]*"' | sed -n '2p' | tr -d '"')"
  printf 'delivered[1]{host,pane,via}:\n  "%s","%s","ssh/%s"\n' "$host" "${pane:-?}" "$tailnet"
  printf '%s\n' "$out" >&2
  exit 0
else
  printf 'undelivered[1]{host,why}:\n  "%s","%s"\n' "$host" "$(printf '%s' "$out" | tr '\n' ' ')"
  exit 1
fi
