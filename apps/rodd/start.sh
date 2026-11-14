#!/usr/bin/env bash
# start.sh — raise Rödd in ONE command, in the ONE order that works.
#
#   apps/rodd/start.sh            raise: clear strays · host · tunnel · toolbox · window
#   apps/rodd/start.sh --headless raise the same pipeline and the terminal client, no window
#   apps/rodd/start.sh --check    report what is up, change nothing
#   apps/rodd/start.sh --stop     lower the window, the toolbox and the tunnel
#   apps/rodd/start.sh --install-unit  render ymir-rodd.service, ExecStart naming the pin
#
# Why a script: the host serves ONE session, and every stray client — a terminal, a probe,
# a second window — takes it and leaves the face silent. This door owns that single seat,
# so the operator never has to reason about it.
set -uo pipefail
APP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$APP/../.." && pwd)"
RODD_HOME=""; . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null && ymir_home_root RODD_HOME   # the one resolver
PORT_HOST="${RODD_HOST_PORT:-8890}"
PORT_BOX="${RODD_TOOLBOX_PORT:-8891}"
PY="${RODD_PYTHON:-$HOME/venvs/s2s/bin/python}"   # allow-home-default: the engine lives in the seat own venv
say() { printf '%-44s %s\n' "$1" "$2"; }

# ── Rödd runs the PIN (plan 257 H7) ──────────────────────────────────────────
# Her window, her tool server and her pipeline execute the pinned runtime (RULES/02 §7),
# never this working tree: an agent that switched ~/ymir to a branch used to change the code
# she ran at her next restart. A start from any other checkout hands over to the pin's own
# start.sh; with no pin she refuses in ONE named line. `--stop` is never refused (lowering
# her is always allowed), and YMIR_RODD_TREE=1 is the loud override for testing this face.
#   apps/rodd/start.sh --install-unit   render ymir-rodd.service (ExecStart names the pin) so
#                                       bin/gates/guards/runtime-pinned-guard.sh can see her
if [ "${1:-}" != "--stop" ] && [ "${YMIR_RODD_TREE:-0}" != 1 ]; then
  # shellcheck source=../../bin/pi/arm-pin-lib.sh
  . "$ROOT/bin/pi/arm-pin-lib.sh"
  RODD_PIN=""; arm_pin_dir RODD_PIN
  if [ -z "$RODD_PIN" ]; then
    say "Rödd refuses to start" "no pinned runtime (YMIR_RUNTIME_DIR in <home>/config/runtime.env) — bin/engine/runtime-deploy.sh"
    exit 1
  fi
  if [ "$(_arm_real "$RODD_PIN")" != "$(_arm_real "$ROOT")" ]; then
    if [ ! -x "$RODD_PIN/apps/rodd/start.sh" ] || [ "${YMIR_RODD_PINNED:-0}" = 1 ]; then
      say "Rödd refuses to start" "the pinned runtime $RODD_PIN has no runnable apps/rodd/start.sh — bin/engine/runtime-deploy.sh"
      exit 1
    fi
    exec env YMIR_RODD_PINNED=1 bash "$RODD_PIN/apps/rodd/start.sh" "$@"
  fi
  if [ "${1:-}" = "--install-unit" ]; then
    unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    mkdir -p "$unit_dir"
    cat >"$unit_dir/ymir-rodd.service" <<UNIT
# ymir-rodd.service — Rödd, the voice of Ymir, run from the PINNED runtime (plan 257 H7).
# Rendered by apps/rodd/start.sh --install-unit; the ExecStart names the pin so
# bin/gates/guards/runtime-pinned-guard.sh sees her like every other surface.
[Unit]
Description=Rödd — the voice of Ymir (pinned runtime)
After=graphical-session.target

[Service]
Type=oneshot
RemainAfterExit=yes
Environment=YMIR_RUNTIME_DIR=$RODD_PIN
ExecStart=/bin/bash $RODD_PIN/apps/rodd/start.sh
ExecStop=/bin/bash $RODD_PIN/apps/rodd/start.sh --stop
UNIT
    say "unit rendered" "$unit_dir/ymir-rodd.service (systemctl --user daemon-reload && systemctl --user start ymir-rodd)"
    exit 0
  fi
fi
# The electron binary is PROBED, never pinned to one distro release: this box moved
# electron41 → electron43 and a hard path turned a working app into "No such file".
resolve_electron() {
  # plan 275 S10 (2026-11-12): the ONE resolver (bin/desktop/electron-lib.sh), the release's own Electron only. The
  # old probe fell back to another app's runtime and to the distribution's /usr/lib/electron*, which pacman upgrades
  # on its own schedule — so an app ran on whatever Electron was lying around, and broke when that moved.
  [ -n "${RODD_ELECTRON:-}" ] && { printf '%s' "$RODD_ELECTRON"; return 0; }
  local tree; tree="$(dirname "$(dirname "$APP")")"
  [ -r "$tree/bin/desktop/electron-lib.sh" ] || return 1
  ( . "$tree/bin/desktop/electron-lib.sh"; electron_bin "$APP" "$tree" )
}
ELECTRON="$(resolve_electron)"
is_local_seat() { [ "$1" = "$(hostname -s)" ] || [ "$1" = localhost ] || [ "$1" = 127.0.0.1 ]; }
strays() { ps -eo pid,args | grep -E "s2s/bin/python .* talk|(electron[0-9]*|node_modules/electron/dist)/electron .*apps/rodd" | grep -v grep | awk '{print $1}'; }
# plan 275 (2026-11-12): the window is closed through its MAIN process only, and given time to close its own helpers.
# Every process above was sent SIGTERM at once — the GPU, renderer and audio helpers died under the main process,
# which treats a helper vanishing as fatal and traps: two Electron cores and two crash notices on his desk tonight
# (22:25:52, 23:36:36). The main Electron process is the one without `--type=`; the voice client is a python process.
rodd_mains() { strays | while read -r p; do tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q -- '--type=' || echo "$p"; done; }
lower_rodd() {
  local p alive
  for p in $(rodd_mains); do kill -TERM "$p" 2>/dev/null; done
  for _ in $(seq 1 25); do alive=$(rodd_mains); [ -z "$alive" ] && return 0; sleep 0.2; done
  for p in $(rodd_mains); do kill -KILL "$p" 2>/dev/null; done   # it would not close in five seconds
}
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
  # plan 275 S16 (2026-11-12): ask the voice door, the one resolver of the engine's host. Rödd used to call any
  # machine with an answering :8080 its own host — nidavellir's small local server made it skip the tunnel to the
  # real engine on heimdall, and its microphone stream had nothing to connect to.
  s="$(bash "$ROOT/bin/voice/voice-door.sh" which-host 2>/dev/null | tail -1)"
  [ -n "$s" ] && { printf '%s' "$s"; return 0; }
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
    lower_rodd
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

# 0 · Rödd runs the PIN (plan 257 H7). Her code root is the pinned runtime the units run —
# YMIR_RUNTIME_DIR, else $YMIR_HOME/config/runtime.env — never the working tree this script
# may have been launched from. A start from anywhere else hands over to the pinned copy;
# an absent pin is ONE named line and no Rödd. (To run a tree on purpose, name it:
# YMIR_RUNTIME_DIR=<that tree> — an explicit pin, never a silent one.)
resolve_pin() {
  local home conf dir
  dir="${YMIR_RUNTIME_DIR:-}"
  if [ -z "$dir" ]; then
    home="${YMIR_HOME:-$HOME/Documents/ymirhome}"   # allow-home-default: the one home, resolved then used
    conf="$home/config/runtime.env"
    [ -r "$conf" ] && dir="$(sed -n 's/^[[:space:]]*YMIR_RUNTIME_DIR[[:space:]]*=[[:space:]]*//p' "$conf" | head -1 | tr -d "\"'")"
    dir="${dir//\$\{HOME\}/$HOME}"; dir="${dir//\$HOME/$HOME}"
  fi
  printf '%s' "$dir"
}
PIN="$(resolve_pin)"
if [ -z "$PIN" ]; then
  say "Rödd refuses to start" "no pinned runtime is named (YMIR_RUNTIME_DIR, or runtime.env in the home)"; exit 1
fi
if [ ! -x "$PIN/apps/rodd/start.sh" ]; then
  say "Rödd refuses to start" "the pin $PIN carries no apps/rodd — run bin/engine/runtime-deploy.sh"; exit 1
fi
if [ "$(cd "$PIN/apps/rodd" && pwd -P)" != "$(cd "$APP" && pwd -P)" ]; then
  say "handing over to the pin" "$PIN/apps/rodd/start.sh"
  YMIR_RUNTIME_DIR="$PIN" exec "$PIN/apps/rodd/start.sh" "$@"
fi
export YMIR_RUNTIME_DIR="$PIN"
say "code root (the pin)" "$PIN"

# 1 · clear every stray client — one seat, one client
n=$(rodd_mains | wc -l)
lower_rodd
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
  # plan 275 (2026-11-12): the head is the MIND HE CHOSE in Rödd's settings (bin/voice/rodd-head.py, kept in the private
  # home), resolved by the voice door. This launcher used to force nidavellir's 3050-tuned alias on every host; the
  # door reads his choice only when no head is forced, so his online mind was never used, heimdall's rail answered
  # `400 model not found`, the engine exited after 18 s, and Rödd never spoke on either machine.
  HEAD="${RODD_HEAD_MODEL:-}"; RODD_CAMERA=0
  # her eyes (plan 275, 2026-11-12, his question: "Why can't she look through the webcam anymore?"): the camera is
  # offered whenever the mind behind her can SEE — a model whose name says vision, or one the open catalog
  # (models.dev, cached in the home) lists with image input. His opencode go mind, deepseek-v4.1-flash, takes images;
  # the old rule offered the camera only with --vision, which forced the local vision model instead of his mind.
  _mind="${HEAD:-$(python3 "$ROOT/bin/voice/rodd-head.py" env 2>/dev/null | sed -n 's/^RODD_VOICE_HEAD_MODEL=//p' | head -1)}"
  # the engine may run on another machine (nidavellir talks to heimdall's): then the mind that answers is THAT
  # machine's choice, so it is asked there — nidavellir judged by its own empty setting and hid the camera (plan 275)
  if [ -z "$HEAD" ] && ! is_local_seat "$seat"; then
    _remote="$(ssh -o BatchMode=yes -o ConnectTimeout=5 "$seat" 'd=${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}; python3 $d/bin/voice/rodd-head.py env' 2>/dev/null | sed -n 's/^RODD_VOICE_HEAD_MODEL=//p' | head -1)"
    [ -n "$_remote" ] && _mind="$_remote"
  fi
  if [ -n "$_mind" ] && python3 - "$_mind" "$RODD_HOME/state/models.dev.json" <<'PY' 2>/dev/null
import json, re, sys
mind, cat = sys.argv[1], sys.argv[2]
if re.search(r"vision|-vl\b|vl-|llava|minicpm-v", mind, re.I): sys.exit(0)
try:
    d = json.load(open(cat))
except Exception:
    sys.exit(1)
for prov in d.values():
    m = (prov.get("models") or {}).get(mind)
    if m and "image" in ((m.get("modalities") or {}).get("input") or []):
        sys.exit(0)
sys.exit(1)
PY
  then RODD_CAMERA=1; fi
  if [ -n "$HEAD" ]; then say "head" "$HEAD (RODD_HEAD_MODEL)"
  else say "head" "the mind chosen in Rödd's settings (${_mind:-none chosen})$([ "$RODD_CAMERA" = 1 ] && echo ' — it can see: the camera is offered')"; fi
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
  # the head is passed only when one is forced (an expansion cannot be an assignment prefix, so `env` carries it)
  head_env=(); [ -n "$HEAD" ] && head_env=("YMIR_VOICE_HEAD_MODEL=$HEAD")
  env CUDA_VISIBLE_DEVICES="${YMIR_VOICE_CUDA:-}" \
    YMIR_VOICE_HOST="$seat" "${head_env[@]}" \
    YMIR_VOICE_STT_DEVICE="${YMIR_VOICE_STT_DEVICE:-cpu}" YMIR_VOICE_STT_COMPUTE="${YMIR_VOICE_STT_COMPUTE:-int8}" \
    "$ROOT/bin/voice/voice-door.sh" host --now 2>&1 | tail -1
else
  ssh -o BatchMode=yes -o ConnectTimeout=6 "$seat" \
    "cd ~/ymir-runtime && ${HEAD:+YMIR_VOICE_HEAD_MODEL='$HEAD'} YMIR_VOICE_STT_DEVICE=cuda YMIR_VOICE_STT_COMPUTE=float16 ./bin/voice/voice-door.sh host --now" 2>&1 | tail -1
fi

# 3b · warm the head. The pipeline gives the model 20 s before it gives up
# ("OpenAI API read timed out after 20.0s"), and a COLD load of the 35B MoE costs
# 18.8 s — a first turn asked cold is a coin toss. Warm, the same answer takes 1.6 s.
# So the head is woken with one word here, while nobody is waiting for a reply.
warm_head() {
  local t0 t1 ms body url
  # only a head on the local rail is warmed here; his chosen online mind needs no warming
  [ -n "$HEAD" ] || return 0
  # plan 271: loading a model on the rail is the heaviest thing this door does to the desk's GPU; during a
  # call it is skipped (the first turn is slower, nothing breaks) unless he says "now".
  if ! "$ROOT/bin/desk/in-call.sh" check --what "warming the head" 2>/dev/null; then
    say "head not warmed" "a call holds the microphone — the first turn will be slower"; return 0
  fi
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
# her web search: the house's own SearXNG, raised in the background so the window never waits for it (plan 275)
setsid bash "$ROOT/bin/voice/search-ensure.sh" > /tmp/rodd-search.log 2>&1 < /dev/null &

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
        "$ROOT/bin/voice/voice-door.sh" host --now 2>&1 | tail -1
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
# The DevTools door: the app's fixed loopback port (bin/desktop/app-lib.sh, plan 275 item 19), always on, so
# her window can be inspected without a restart. YMIR_DEVTOOLS_PORT still wins, for a one-off probe.
[ -r "$ROOT/bin/desktop/app-lib.sh" ] && . "$ROOT/bin/desktop/app-lib.sh"
RODD_DEVTOOLS_PORT="${YMIR_DEVTOOLS_PORT:-$(app_devtools_port rodd 2>/dev/null || true)}"
[ -n "$ELECTRON" ] || { say "no electron binary" "install electron43 or run npm ci in apps/rodd"; exit 1; }
# The frame's buttons are the platform layer's question (bin/host/host-sense.sh): on a tiling
# compositor (Omarchy's Hyprland) the window is frameless and draws no _ □ ×, elsewhere the
# platform keeps its own. The answer crosses into the shell as YMIR_WINDOW_BUTTONS (Rule 05).
if [ -r "$ROOT/bin/desktop/app-lib.sh" ]; then
  # shellcheck source=../../bin/desktop/app-lib.sh
  . "$ROOT/bin/desktop/app-lib.sh"
  YMIR_WINDOW_BUTTONS="$(app_window_buttons)"
fi
export YMIR_WINDOW_BUTTONS="${YMIR_WINDOW_BUTTONS:-on}"
setsid env SPEECH_TO_SPEECH_URL="ws://127.0.0.1:$PORT_HOST/v1/realtime" \
  "$ELECTRON" --remote-debugging-port="${RODD_DEVTOOLS_PORT:-9222}" "$APP" > /tmp/rodd-app.log 2>&1 < /dev/null &
# The window maps in about two seconds; a fixed 14 s sleep only made the click wait — and it is the click that
# waits, because ymir-app restarts her unit and a oneshot unit does not return until this script does (measured
# 2026-11-14: ~69 s from click to window, of which this sleep was 12 s of nothing). Poll for the window instead.
for _i in $(seq 1 60); do
  ps -eo args 2>/dev/null | grep 'apps/rodd' | grep -qv 'grep' && break
  sleep 0.5
done
say "window" "$(ps -eo args | grep -c 'apps/rodd')"
say "next" "apps/rodd/smoke.sh 45   # must end: assistant audio arrived PASS"
