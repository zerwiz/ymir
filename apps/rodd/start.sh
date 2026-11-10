#!/usr/bin/env bash
# start.sh — raise Rödd in ONE command, in the ONE order that works.
#
#   apps/rodd/start.sh            raise: clear strays · host · tunnel · toolbox · window
#   apps/rodd/start.sh --headless raise the same pipeline and the terminal client, no window
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
host_seats() {
  python3 - <<'PY'
import json, os
try:
    home = os.environ.get("YMIR_HOME") or os.path.expanduser("~/Documents/ymirhome")  # allow-home-default: the one home, resolved then used
    fleet = json.load(open(os.path.join(home, "hodd/data/fleet.json")))
    ears = [e for e in (fleet.get("ear") or [fleet.get("heart", "")]) if e]
    print(" ".join(ears))
except Exception:
    print("")
PY
}
# The host is the first seat that ANSWERS, in the fleet's own order, with this machine
# last. A registry entry is a wish, not a fact: on 2026-11-09 the ear (heimdall) was
# unreachable, ssh timed out, and the whole start failed although this box can host.
# The host is the first seat that can ACTUALLY serve, not the first that answers ssh:
#   · this machine first, when it carries a model rail (the head is here, so the
#     pipeline should be here — heimdall answered ssh on 2026-11-09 while its
#     pipeline could not start at all, and the whole start died there);
#   · then the fleet's ears in their own order.
local_rail() { curl -s -o /dev/null --max-time 2 "${YMIR_VOICE_HEAD_URL:-http://127.0.0.1:8080/v1}/models"; }
host_seat() {
  local s me
  me="$(hostname -s)"
  if local_rail; then printf '%s' "$me"; return 0; fi
  for s in $(host_seats) "$me"; do
    if is_local_seat "$s"; then printf '%s' "$s"; return 0; fi
    if ssh -o BatchMode=yes -o ConnectTimeout=3 "$s" true >/dev/null 2>&1; then printf '%s' "$s"; return 0; fi
    printf '%-44s %s\n' "host candidate down" "$s" >&2   # stderr: host_seat() is read as a value
  done
  return 1
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
    say "headless client" "$(ps -eo args | grep -c ' talk --url')"
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
  # The head must be one this rail can actually LOAD, not merely one it lists:
  # qwen3.6-35b-a3b@iq3_s answers 500 "failed to load" on this box (2026-11-09 07:35),
  # while the 3050-tuned qwen3.6-35b-a3b-3050@iq2_xxs loads and answers.
  HEAD="${RODD_HEAD_MODEL:-qwen3.6-35b-a3b-3050@iq2_xxs}"; RODD_CAMERA=0; say "head" "fast MoE, 3050-tuned (no camera — start with --vision for pictures)"
fi
export RODD_CAMERA
if is_local_seat "$seat"; then
  # The head owns the GPU. Loading Whisper on CUDA beside a 35B MoE fails with
  # "CUDA failed with error out of memory" and takes the whole host down (measured
  # 2026-11-09 07:31). The ear of a small.en model is cheap on the CPU; the card is
  # for the head. Override with YMIR_VOICE_STT_DEVICE on a box with room for both.
  # Hide the card from the pipeline entirely: this box sees ~3.7 GiB of it, the head's
  # llama-server already claims that, and torch OOMs the moment it touches CUDA
  # ("Tried to allocate 2.00 MiB ... 1.75 MiB is free", 2026-11-09 07:38). Kokoro and
  # Whisper on the CPU cost a beat and leave the head its memory.
  CUDA_VISIBLE_DEVICES="${YMIR_VOICE_CUDA:-}" \
  YMIR_VOICE_HOST="$seat" YMIR_VOICE_HEAD_MODEL="$HEAD" \
  YMIR_VOICE_STT_DEVICE="${YMIR_VOICE_STT_DEVICE:-cpu}" YMIR_VOICE_STT_COMPUTE="${YMIR_VOICE_STT_COMPUTE:-int8}" \
    "$ROOT/bin/voice/voice-door.sh" host 2>&1 | tail -1
else
  ssh -o BatchMode=yes -o ConnectTimeout=6 "$seat" \
    "cd ~/ymir && YMIR_VOICE_HEAD_MODEL='$HEAD' YMIR_VOICE_STT_DEVICE=cuda YMIR_VOICE_STT_COMPUTE=float16 ./bin/voice/voice-door.sh host" 2>&1 | tail -1
fi

# 3b · warm the head. The pipeline gives the model 20 s before it gives up
# ("OpenAI API read timed out after 20.0s"), and a COLD load of the 35B MoE costs
# 18.8 s — a first turn asked cold is a coin toss. Warm, the same answer takes 1.6 s.
# So the head is woken with one word here, while nobody is waiting for a reply.
warm_head() {
  local t0 t1 ms body url
  url="${YMIR_VOICE_HEAD_URL:-http://127.0.0.1:8080/v1}"
  t0=$(date +%s%N)
  body=$(curl -s --max-time 300 "$url/chat/completions" -H 'Content-Type: application/json' \
    -d "{\"model\":\"$HEAD\",\"messages\":[{\"role\":\"user\",\"content\":\"Say ok\"}],\"max_tokens\":2}" || true)
  t1=$(date +%s%N); ms=$(( (t1-t0)/1000000 ))
  case "$body" in
    *'"choices"'*) say "head warm" "$HEAD · ${ms} ms (a warm turn is ~1.6 s)" ;;
    *)             say "head NOT warm" "$HEAD · ${ms} ms — check the rail before speaking" ;;
  esac
}
warm_head

# 4 · the toolbox — the house's fourteen hands
if ! curl -s --max-time 2 "http://127.0.0.1:$PORT_BOX/health" | grep -q '"ok"'; then
  setsid python3 "$ROOT/bin/voice/voice-toolbox.py" --port "$PORT_BOX" > /tmp/rodd-toolbox.log 2>&1 < /dev/null &
  sleep 2
fi
say "toolbox" "$(curl -s --max-time 3 "http://127.0.0.1:$PORT_BOX/health" | head -c 40)"

# 5 · the window — or, when asked, the engine's own terminal client and no face at all.
# A touchscreen seat with a running shell wants the buttons, not an Electron window over the
# work; the pipeline is the same and the microphone belongs to the client either way.
if [ "${1:-}" = "--headless" ] || [ "${RODD_HEADLESS:-0}" = "1" ]; then
  say "face" "skipped (headless)"
  seat_client() {
    # YMIR_VOICE_HOST is named, not probed: the door's own probe walks the fleet's ears,
    # and this seat's local host is not one of them, so it refused with "no host seat
    # reachable" while the pipeline was answering on loopback.
    setsid env YMIR_VOICE_PANE=0 YMIR_VOICE_HOST="$seat" "$ROOT/bin/voice/voice-door.sh" client \
      > /tmp/rodd-headless.log 2>&1 < /dev/null &
    sleep 5
  }
  seat_client
  # The pipeline serves ONE session. A window that closed uncleanly, or a client that
  # was killed, leaves its slot held and every new client is refused — the face deals
  # with the same leak by restarting the host, and so does this door.
  if grep -q session_limit_reached /tmp/rodd-headless.log 2>/dev/null; then
    say "session slot held" "restarting the pipeline"
    "$ROOT/bin/voice/voice-door.sh" host --stop >/dev/null 2>&1
    sleep 2
    if is_local_seat "$seat"; then
      CUDA_VISIBLE_DEVICES="${YMIR_VOICE_CUDA:-}" \
      YMIR_VOICE_HOST="$seat" YMIR_VOICE_HEAD_MODEL="$HEAD" \
      YMIR_VOICE_STT_DEVICE="${YMIR_VOICE_STT_DEVICE:-cpu}" YMIR_VOICE_STT_COMPUTE="${YMIR_VOICE_STT_COMPUTE:-int8}" \
        "$ROOT/bin/voice/voice-door.sh" host 2>&1 | tail -1
    fi
    seat_client
  fi
  say "client state" "$(grep -oE 'session_limit_reached|Ready — start speaking' /tmp/rodd-headless.log | tail -1)"
  say "headless client" "$(ps -eo args | grep -c ' talk --url' )"
  say "log" "/tmp/rodd-headless.log"
  say "stop" "apps/rodd/start.sh --stop"
  exit 0
fi

# 5 · the window
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"
[ -n "$ELECTRON" ] || { say "no electron binary" "install electron43 or run npm ci in apps/rodd"; exit 1; }
setsid env SPEECH_TO_SPEECH_URL="ws://127.0.0.1:$PORT_HOST/v1/realtime" \
  "$ELECTRON" --remote-debugging-port=9222 "$APP" > /tmp/rodd-app.log 2>&1 < /dev/null &
sleep 14
say "window" "$(ps -eo args | grep -c 'apps/rodd')"
say "next" "apps/rodd/smoke.sh 45   # must end: assistant audio arrived PASS"
