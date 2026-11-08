#!/usr/bin/env bash
# start.sh — raise Rödd in ONE command, in the ONE order that works.
#
#   apps/rodd/start.sh            raise: clear strays · host · tunnel · toolbox · window
#   apps/rodd/start.sh --check    report what is up, change nothing
#   apps/rodd/start.sh --stop     lower the window, the toolbox and the tunnel
#
# Why a script: the host serves ONE session, and every stray client — a terminal, a probe,
# a second window — takes it and leaves the face silent. This door owns that single seat,
# so the operator never has to reason about it.
set -uo pipefail
APP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$APP/../.." && pwd)"
PORT_HOST="${RODD_HOST_PORT:-8890}"
PORT_BOX="${RODD_TOOLBOX_PORT:-8891}"
PY="${RODD_PYTHON:-$HOME/venvs/s2s/bin/python}"   # allow-home-default: the engine lives in the seat own venv
say() { printf '%-44s %s\n' "$1" "$2"; }
# The electron binary is PROBED, never pinned to one distro release: this box moved
# electron41 → electron43 and a hard path turned a working app into "No such file".
resolve_electron() {
  [ -n "${RODD_ELECTRON:-}" ] && { printf '%s' "$RODD_ELECTRON"; return 0; }
  [ -x "$APP/node_modules/electron/dist/electron" ] && { printf '%s' "$APP/node_modules/electron/dist/electron"; return 0; }
  local e
  for e in $(ls -d /usr/lib/electron*/electron 2>/dev/null | sort -Vr); do
    [ -x "$e" ] && { printf '%s' "$e"; return 0; }
  done
  command -v electron 2>/dev/null
}
ELECTRON="$(resolve_electron)"
is_local_seat() { [ "$1" = "$(hostname -s)" ] || [ "$1" = localhost ] || [ "$1" = 127.0.0.1 ]; }
strays() { ps -eo pid,args | grep -E "s2s/bin/python .* talk|(electron[0-9]*|node_modules/electron/dist)/electron .*apps/rodd" | grep -v grep | awk '{print $1}'; }
host_seat() {
  python3 - <<'PY'
import json, os
try:
    home = os.environ.get("YMIR_HOME") or os.path.expanduser("~/Documents/ymirhome")  # allow-home-default: the one home, resolved then used
    fleet = json.load(open(os.path.join(home, "hodd/data/fleet.json")))
    print((fleet.get("ear") or [fleet.get("heart", "")])[0])
except Exception:
    print("")
PY
}

case "${1:-}" in
  --stop)
    for p in $(strays); do kill "$p" 2>/dev/null; done
    # the toolbox is stopped by the pid that holds its port — never a blanket pattern kill,
    # whose match also takes the shell running it (measured twice on 2026-10-20)
    port_pid=$(ss -ltnp 2>/dev/null | grep ":$PORT_BOX " | grep -oE 'pid=[0-9]+' | head -1 | cut -d= -f2)
    [ -n "${port_pid:-}" ] && kill "$port_pid" 2>/dev/null
    for t in $(ps -eo pid,args | grep "8890:127.0.0.1:$PORT_HOST" | grep -v grep | awk '{print $1}'); do kill "$t" 2>/dev/null; done
    say "lowered" "window · toolbox · tunnel"
    exit 0 ;;
  --check)
    say "host $PORT_HOST answers" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:$PORT_HOST/" || echo down)"
    say "tunnel listens" "$(ss -tln 2>/dev/null | grep -c ":$PORT_HOST")"
    say "toolbox answers" "$(curl -s --max-time 3 "http://127.0.0.1:$PORT_BOX/health" | head -c 40)"
    say "window running" "$(ps -eo args | grep -c 'apps/rodd')"
    exit 0 ;;
esac

# 1 · clear every stray client — one seat, one client
n=$(strays | wc -l)
for p in $(strays); do kill "$p" 2>/dev/null; done
sleep 2
say "stray clients cleared" "$n"

# 1 · the face must be there before anything claims to speak through it — a clone that
# has never fetched it (or one whose pinned tag moved) builds it here, so ONE command
# always ends in a window that works, after an install or an update as much as on day one.
if ! face="$("$APP/setup.sh" --check 2>/dev/null)"; then
  say "face" "${face:-missing} — building it (apps/rodd/setup.sh)"
  "$APP/setup.sh" 2>&1 | tail -3 || { say "face build FAILED" "run apps/rodd/setup.sh by hand"; exit 1; }
fi

# 2 · the tunnel (leave it if it already forwards; a host seat that IS this machine
# needs none — ssh-to-self fails on a box with no key seated for its own login, which
# is every dev seat, and that refused the whole start for no reason at all)
seat="$(host_seat)"
[ -n "$seat" ] || { say "no host seat in the fleet registry" "FAIL"; exit 1; }
if is_local_seat "$seat"; then
  say "host seat" "$seat (this machine — no tunnel to open)"
elif ss -tln 2>/dev/null | grep -q ":$PORT_HOST"; then
  say "tunnel already open" "kept"
else
  ssh -f -N -o ExitOnForwardFailure=yes -o BatchMode=yes -L "$PORT_HOST:127.0.0.1:$PORT_HOST" "$seat" && say "tunnel opened" "$seat"
fi

# 3 · the host pipeline, fresh (a leaked slot is why the window goes silent)
# TWO heads, chosen per session: words want the fast MoE (~2 s a turn); a camera wants the
# vision head (slower per turn, but it can SEE — the fast MoE answers an image part with
# `500 image input is not supported`, and that failure sticks to the whole session).
# RODD_CAMERA carries the choice to the window, which offers the camera only when the
# head behind it can see it.
if [ "${1:-}" = "--vision" ] || [ "${RODD_VISION:-0}" = "1" ]; then
  HEAD="gemma-4-12b-vision"; RODD_CAMERA=1; say "head" "vision — the camera is on (turns are slower)"
else
  HEAD="qwen3.6-35b-a3b@iq3_s-fast"; RODD_CAMERA=0; say "head" "fast MoE (no camera — start with --vision for pictures)"
fi
export RODD_CAMERA
if is_local_seat "$seat"; then
  YMIR_VOICE_HOST="$seat" YMIR_VOICE_HEAD_MODEL="$HEAD" YMIR_VOICE_STT_DEVICE=cuda YMIR_VOICE_STT_COMPUTE=float16 \
    "$ROOT/bin/voice/voice-door.sh" host 2>&1 | tail -1
else
  ssh -o BatchMode=yes -o ConnectTimeout=6 "$seat" \
    "cd ~/ymir && YMIR_VOICE_HEAD_MODEL='$HEAD' YMIR_VOICE_STT_DEVICE=cuda YMIR_VOICE_STT_COMPUTE=float16 ./bin/voice/voice-door.sh host" 2>&1 | tail -1
fi

# 4 · the toolbox — the house's fourteen hands
if ! curl -s --max-time 2 "http://127.0.0.1:$PORT_BOX/health" | grep -q '"ok"'; then
  setsid python3 "$ROOT/bin/voice/voice-toolbox.py" --port "$PORT_BOX" > /tmp/rodd-toolbox.log 2>&1 < /dev/null &
  sleep 2
fi
say "toolbox" "$(curl -s --max-time 3 "http://127.0.0.1:$PORT_BOX/health" | head -c 40)"

# 5 · the window
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"
[ -n "$ELECTRON" ] || { say "no electron binary" "install electron43 or run npm ci in apps/rodd"; exit 1; }
setsid env SPEECH_TO_SPEECH_URL="ws://127.0.0.1:$PORT_HOST/v1/realtime" \
  "$ELECTRON" --remote-debugging-port=9222 "$APP" > /tmp/rodd-app.log 2>&1 < /dev/null &
sleep 14
say "window" "$(ps -eo args | grep -c 'apps/rodd')"
say "next" "apps/rodd/smoke.sh 45   # must end: assistant audio arrived PASS"
