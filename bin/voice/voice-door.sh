#!/usr/bin/env bash
# voice-door.sh — the real-time voice door: speak to Ymir on whatever seat you are at.
#
# One door, two roles, decided by PROBE — never by a table:
#   host    this seat runs the streaming pipeline (VAD → ear → head → mouth) and
#           answers on a loopback Realtime socket
#   client  this seat's microphone and speakers are connected to a host, local or
#           on another machine, over an ssh tunnel (the host stays loopback-only)
#
# No machine name, address, key or path is written here: the host is read from
# the operator's own fleet registry ($YMIR_HOME) or given in the environment, and
# every setting has one documented default (RULES/07). Nothing private is stored
# in this repo (RULES/04).
#
# Usage:
#   voice-door.sh status            what this seat can do, and what answers now
#   voice-door.sh start             the one verb: raise the host if needed, open the tunnel,
#                                   and seat the voice in a herdr pane (or this terminal)
#   voice-door.sh stop [--host]     lower the client and tunnel; --host lowers the pipeline
#   voice-door.sh host [--stop] [--now]  raise/stop the pipeline here (--now: the operator says go, call or not)
#   voice-door.sh client            speak and listen here, against a host
#   voice-door.sh log [--lines N]   what the voice has DONE: turns, tool calls, well recalls
#   voice-door.sh plan              print exactly what would run, change nothing
#   voice-door.sh --install         install the engine into its own venv (asks first)
#
# Env (all optional, all defaulted):
#   YMIR_VOICE_PORT          host port                      (default 8890)
#   YMIR_VOICE_HOST          host machine, as ssh knows it  (default: probe fleet order)
#   YMIR_VOICE_STT           stt backend                     (default faster-whisper)
#   YMIR_VOICE_STT_MODEL     stt model                       (default small.en)
#   YMIR_VOICE_STT_DEVICE    auto|cpu|cuda                   (default cpu)
#   YMIR_VOICE_STT_COMPUTE   compute type                    (default int8)
#   YMIR_VOICE_TTS           tts backend                     (default kokoro)
#   YMIR_VOICE_TTS_VOICE     kokoro voice                    (default af_nicole)
#   YMIR_VOICE_HEAD_URL      OpenAI-compatible chat endpoint  (default http://127.0.0.1:8080/v1)
#   YMIR_VOICE_HEAD_MODEL    the head model id               (REQUIRED to host)
#   YMIR_VOICE_HEAD_KEY_NAME vault key NAME for the head      (default: the seat's own
#                            rail key in ~/.pi/agent/auth.json)
#   YMIR_VOICE_HEAD_KEY_PROVIDER  the provider name in auth.json (default 'llama-swap';
#                            use 'llamacpp-heimdall' when the head is another seat's rail)
#   YMIR_VOICE_MIN_SILENCE_MS  silence that ends a turn        (default 300)
#   YMIR_VOICE_REOPEN_MS     speculative reopen grace         (default 400)
#   YMIR_VOICE_SMART_TURN_WAIT_MS  endpointing ceiling         (default 500)
#   YMIR_VOICE_PANE          1 = seat the client in a herdr pane  (default 1; 0 = this terminal)
#   YMIR_VOICE_BARGE_IN      1 = let the microphone stay open while it speaks
#                            (default 0: the client blocks the mic during playback,
#                            because there is no echo cancellation — an open mic
#                            hears the assistant's own voice and answers it forever)
#   YMIR_VOICE_BIN           the speech-to-speech binary     (default: probed)
#   YMIR_VOICE_VENV          the venv it lives in            (default $HOME/venvs/s2s)
#
#   YMIR_VOICE_TOOLS         0 = the client may not hand work over   (default 1: on)
#   YMIR_VOICE_NAME          the name it answers to             (default Skirnir)
#
# Exit: 0 ok · 1 not available (said why) · 2 usage.
set -u
VERSION="1.0.0"

ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; s="$d"; while [ "$d" != / ] && { [ ! -d "$d/RULES" ] || [ ! -d "$d/.agents" ]; }; do d="$(dirname "$d")"; done; { [ -d "$d/RULES" ] && [ -d "$d/.agents" ]; } || d="$s"; printf '%s' "$d")"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true; fi
YMIR_HOME="${YMIR_HOME:-}"; [ -n "$YMIR_HOME" ] || ymir_home_root YMIR_HOME 2>/dev/null || true

PORT="${YMIR_VOICE_PORT:-8890}"
HOST_MACHINE="${YMIR_VOICE_HOST:-}"
STT="${YMIR_VOICE_STT:-faster-whisper}"
STT_MODEL="${YMIR_VOICE_STT_MODEL:-small.en}"
# this machine's own voice settings (plan 275): ~/.config/ymir/voice.env, per machine and never the shared home —
# one machine has a compute GPU and room for two conversations, another has neither. Only YMIR_VOICE_* keys are read.
if [ -r "${XDG_CONFIG_HOME:-$HOME/.config}/ymir/voice.env" ]; then
  while IFS='=' read -r _k _v; do
    case "$_k" in YMIR_VOICE_[A-Z_]*) [ -n "${!_k:-}" ] || export "$_k=$(printf '%s' "$_v" | tr -d "\"'")" ;; esac
  done < <(grep -E '^[[:space:]]*YMIR_VOICE_[A-Z_]+=' "${XDG_CONFIG_HOME:-$HOME/.config}/ymir/voice.env")
  # read before: the host was resolved above this block, so a machine that names ITSELF as the voice host was
  # still sent to the fleet's first ear (nidavellir to heimdall)
  HOST_MACHINE="${YMIR_VOICE_HOST:-$HOST_MACHINE}"
fi
STT_DEVICE="${YMIR_VOICE_STT_DEVICE:-cpu}"
STT_COMPUTE="${YMIR_VOICE_STT_COMPUTE:-int8}"
TTS="${YMIR_VOICE_TTS:-kokoro}"
TTS_VOICE="${YMIR_VOICE_TTS_VOICE:-af_nicole}"
HEAD_URL="${YMIR_VOICE_HEAD_URL:-http://127.0.0.1:8080/v1}"
HEAD_MODEL="${YMIR_VOICE_HEAD_MODEL:-}"
HEAD_KEY_NAME="${YMIR_VOICE_HEAD_KEY_NAME:-}"
MIN_SILENCE_MS="${YMIR_VOICE_MIN_SILENCE_MS:-300}"
VAD_THRESH="${YMIR_VOICE_VAD_THRESH:-0.45}"
MIN_SPEECH_MS="${YMIR_VOICE_MIN_SPEECH_MS:-200}"
REOPEN_MS="${YMIR_VOICE_REOPEN_MS:-400}"
SMART_TURN_WAIT_MS="${YMIR_VOICE_SMART_TURN_WAIT_MS:-500}"
BARGE_IN="${YMIR_VOICE_BARGE_IN:-0}"
TOOLS_ON="${YMIR_VOICE_TOOLS:-1}"
PANE="${YMIR_VOICE_PANE:-1}"
CHAT_SIZE="${YMIR_VOICE_CHAT_SIZE:-12}"
PIPELINES="${YMIR_VOICE_PIPELINES:-1}"
VOICE_NAME="${YMIR_VOICE_NAME:-Skirnir}"
OPERATOR_NAME="${YMIR_VOICE_OPERATOR:-Allfather}"
VENV="${YMIR_VOICE_VENV:-$HOME/venvs/s2s}"
STATE_DIR="${YMIR_HOME:-$HOME}/hodd/state/voice"
UNIT="ymir-voice-host.service"
# The engine lets the card go when nobody is on the line (plan 275 item 23): a watcher is
# raised beside it, and it stops the engine after a quiet window. See bin/voice/voice-idle.sh.
IDLE_UNIT="ymir-voice-idle.service"

# ── the head: ONE door, so a switch made in Rödd's settings and a start made in a
# shell cannot disagree. bin/voice/rodd-head.py resolves mode · base_url · model ·
# key (named in the vault, or typed into the panel and kept 0600 in the home). An
# environment value already set wins, which is how a one-off start stays possible.
RODD_RESOLVED_KEY=""
RODD_HEAD_MODE_RESOLVED="local"
RODD_HEAD_CLIENT="plain"
PROXY_PORT="${RODD_PROXY_PORT:-8893}"
if [ -z "$HEAD_MODEL" ] && [ -r "$ROOT/bin/voice/rodd-head.py" ]; then
  while IFS='=' read -r _k _v; do
    case "$_k" in
      RODD_HEAD_MODE)          RODD_HEAD_MODE_RESOLVED="$_v" ;;
      RODD_HEAD_ONLINE_CLIENT) RODD_HEAD_CLIENT="$_v" ;;
      RODD_VOICE_HEAD_URL)     [ -n "$HEAD_URL" ]   || HEAD_URL="$_v" ;;
      RODD_VOICE_HEAD_MODEL)   [ -n "$HEAD_MODEL" ] || HEAD_MODEL="$_v" ;;
      RODD_VOICE_HEAD_API_KEY) RODD_RESOLVED_KEY="$_v" ;;
    esac
  done < <(python3 "$ROOT/bin/voice/rodd-head.py" env --with-key 2>/dev/null || true)
  # an online head is reached through the loopback proxy, which is the only place the
  # headers a hosted gateway demands can be added (see bin/voice/head-proxy.py)
  if [ "$RODD_HEAD_MODE_RESOLVED" = "online" ]; then
    HEAD_URL="http://127.0.0.1:${PROXY_PORT}/v1"
  fi
fi

raise_head_proxy() {
  command -v systemd-run >/dev/null 2>&1 || return 0
  systemctl --user stop rodd-head-proxy.service 2>/dev/null || true
  mkdir -p "$STATE_DIR"
  systemd-run --user --unit=rodd-head-proxy.service --collect \
    --property=StandardOutput=append:"$STATE_DIR/head-proxy.log" \
    --property=StandardError=append:"$STATE_DIR/head-proxy.log" \
    python3 "$ROOT/bin/voice/head-proxy.py" --port "$PROXY_PORT" >/dev/null 2>&1 || return 1
  for _ in $(seq 1 30); do
    curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$PROXY_PORT/health" && return 0
    sleep 0.5
  done
  return 1
}

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,36p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
CMD="${1-}"; shift || true
DO_STOP=0; DO_INSTALL=0; DO_NOW="${YMIR_DESK_NOW:-0}"
case "$CMD" in status|which-host|host|client|plan|--install|install|start|stop|log) ;; *) printf 'error: unknown command %s\nhelp: bin/voice/voice-door.sh [status|host|client|plan|--install]\n' "$CMD" >&2; exit 2 ;; esac
[ "$CMD" = install ] && CMD=--install
while [ $# -gt 0 ]; do case "$1" in --stop) DO_STOP=1 ;; --install) DO_INSTALL=1 ;; --now) DO_NOW=1 ;; *) shift; continue ;; esac; shift; done

have() { command -v "$1" >/dev/null 2>&1; }
say() { printf '%s\n' "$*"; }
err() { printf '%s\n' "$*" >&2; }

# --- discovery (adopt what stands; never guess a binary) ---------------------

find_engine() {
  if [ -n "${YMIR_VOICE_BIN:-}" ] && [ -x "$YMIR_VOICE_BIN" ]; then printf '%s' "$YMIR_VOICE_BIN"; return 0; fi
  if [ -x "$VENV/bin/speech-to-speech" ]; then printf '%s' "$VENV/bin/speech-to-speech"; return 0; fi
  if have speech-to-speech; then command -v speech-to-speech; return 0; fi
  return 1
}

head_key() {
  if [ -n "$HEAD_KEY_NAME" ]; then
    "$ROOT/bin/vault/hodd.sh" emit secrets/platform.env 2>/dev/null \
      | awk -F= -v k="$HEAD_KEY_NAME" '$1==k{sub(/^[^=]*=/,""); print; exit}'
    return 0
  fi
  # the seat's own rail key: a standard pi path, never a served secret (RULES/07 default)
  python3 - "$HOME/.pi/agent/auth.json" "${YMIR_VOICE_HEAD_KEY_PROVIDER:-llama-swap}" <<'PY' 2>/dev/null
import json,sys
p=sys.argv[1]
import sys as _s
names = (_s.argv[2], "llama-swap", "llamacpp")
for name in dict.fromkeys(names):
    try: d=json.load(open(p))
    except Exception: raise SystemExit(0)
    v=d.get(name) if isinstance(d,dict) else None
    if isinstance(v,dict) and v.get("key"):
        print(v["key"]); raise SystemExit(0)
PY
}

# the operator's own registry: the ear order is the fleet's own opinion of who can host
fleet_order() {
  local f="${YMIR_HOME:-$HOME}/hodd/data/fleet.json"
  [ -r "$f" ] || return 0
  python3 - "$f" <<'PY' 2>/dev/null
import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception: raise SystemExit(0)
for h in d.get("ear",[]): print(h)
PY
}

reachable() { timeout 6 ssh -o BatchMode=yes -o ConnectTimeout=5 "$1" true 2>/dev/null; }

resolve_host() {
  [ -n "$HOST_MACHINE" ] && { printf '%s' "$HOST_MACHINE"; return 0; }
  local h
  while IFS= read -r h; do [ -n "$h" ] || continue; reachable "$h" && { printf '%s' "$h"; return 0; }; done < <(fleet_order)
  return 1
}

host_answers() { curl -s -o /dev/null --max-time 3 "http://127.0.0.1:$PORT/" || curl -s -o /dev/null --max-time 3 "http://127.0.0.1:$PORT/docs"; }

# the host's own loopback is the truth: ask it there, over ssh, not through a tunnel
host_answers_on() {
  local m="${1:-}"
  if [ -z "$m" ] || [ "$m" = "$(hostname -s)" ] || [ "$m" = localhost ]; then host_answers; return $?; fi
  timeout 8 ssh -o BatchMode=yes -o ConnectTimeout=5 "$m" \
    "curl -s -o /dev/null --max-time 3 http://127.0.0.1:$PORT/ || curl -s -o /dev/null --max-time 3 http://127.0.0.1:$PORT/docs" 2>/dev/null
}

HOST_ARGV=()
build_host_argv() {
  HOST_ARGV=(
    --stt "$STT" --faster_whisper_stt_model_name "$STT_MODEL"
    --faster_whisper_stt_device "$STT_DEVICE" --faster_whisper_stt_compute_type "$STT_COMPUTE"
    --tts "$TTS" --kokoro_voice "$TTS_VOICE" --kokoro_lang_code a
    --llm_backend chat-completions --responses_api_base_url "$HEAD_URL"
    --responses_api_stream true --model_name "$HEAD_MODEL"
    --init_chat_role system
    --init_chat_prompt "You are $VOICE_NAME, the Allfather's voice. Speak in one or two short sentences. When he asks about his own notes, plans, lists or files, use search_home and read_home_file (never the vault — it is closed to you); when he asks you to record something, use add_todo; for any request with more than one step, FIRST call plan_write and read the numbered steps back to him, and only send after he approves the STEPS; check context_left on a long conversation so you summarise before the window fills; when he asks for work to be done, ask him out loud for permission first — call hand_over WITHOUT confirm, hear his yes, then call again with confirm=true; never send a worker on your own reading of his intent; after sending, tell him you will report when he asks, and when he asks whether a worker is done use errand_state and answer from it — never say a worker finished without checking; when a question is about past work or decisions, call recall first. Never claim a merge or a push: you dispatch, he decides."
    --vad silero --thresh "$VAD_THRESH" --min_speech_ms "$MIN_SPEECH_MS" --min_silence_ms "$MIN_SILENCE_MS" --speculative_reopen_ms "$REOPEN_MS"
    --smart_turn_max_wait_ms "$SMART_TURN_WAIT_MS"
    --num_pipelines "$PIPELINES" --chat_size "${CHAT_SIZE:-12}"
    --log_transcripts --host 127.0.0.1 --port "$PORT" --log_level info
  )
}

# the CUDA-12 wheels CTranslate2 needs when the ear runs on the card (RULES/07: probed, never assumed)
cuda_lib_path() {
  local sp="$VENV/lib/python3.12/site-packages/nvidia"
  [ -d "$sp/cublas/lib" ] || return 0
  printf '%s' "$sp/cublas/lib:$sp/cudnn/lib"
}

# --- commands ---------------------------------------------------------------

cmd_status() {
  local eng host key road
  eng="$(find_engine || true)"
  host="$(resolve_host || true)"
  key="$([ -n "$HEAD_KEY_NAME" ] && echo "ref:$HEAD_KEY_NAME" || echo "none")"
  road="local"
  [ -n "$host" ] && [ "$host" != "$(hostname -s)" ] && road="tunnel"
  printf 'voice[7]{key,value}:\n'
  printf '  "engine","%s"\n' "${eng:-ABSENT — run: voice-door.sh --install}"
  printf '  "port","%s"\n' "$PORT"
  printf '  "host seat","%s"\n' "${host:-none reachable}"
  printf '  "road","%s"\n' "$road"
  printf '  "head","%s %s"\n' "$HEAD_URL" "${HEAD_MODEL:-MODEL-UNSET}"
  printf '  "head key","%s"\n' "$key"
  printf '  "answers now","%s"\n' "$([ -n "$host" ] && host_answers_on "$host" && echo 'yes (on the host seat)' || echo no)"
  [ -n "${eng:-}" ] || return 1
  return 0
}

cmd_plan() {
  local eng
  eng="$(find_engine || echo "$VENV/bin/speech-to-speech")"
  say "# host on this seat:"
  say "systemd-run --user --unit=$UNIT --collect \\"
  say "  --setenv=VIRTUAL_ENV=$VENV --setenv=PATH=$VENV/bin:/usr/local/bin:/usr/bin:/bin \\"
  build_host_argv; printf '  %s serve' "$eng"; printf ' %q' "${HOST_ARGV[@]}"; printf '\n' 
  say "# client on this seat (tunnel keeps the host loopback-only):"
  say "ssh -N -L $PORT:127.0.0.1:$PORT <host seat> &"
  say "$eng talk --url ws://127.0.0.1:$PORT/v1/realtime --log-transcripts"
  return 0
}

cmd_host() {
  local eng hk
  if [ "$DO_STOP" = 1 ]; then
    systemctl --user stop "$IDLE_UNIT" 2>/dev/null || true
    systemctl --user stop "$UNIT" 2>/dev/null && say "stopped $UNIT" || say "was not running"
    return 0
  fi
  eng="$(find_engine || true)"
  [ -n "$eng" ] || { err "error: the engine is absent; run: bin/voice/voice-door.sh --install"; return 1; }
  if [ -z "$HEAD_MODEL" ]; then
    err "error: YMIR_VOICE_HEAD_MODEL is unset — this door refuses to guess a brain (RULES/07)."
    err "hint: any model the seat's own catalog lists, e.g. 'bin/model/catalog.sh' then set it."
    return 1
  fi
  # the resolver's key wins: it knows WHICH key the chosen head needs (the rail's own
  # key for local, the named or typed one for an online endpoint). Falling back to
  # the rail key for an online head sent the wrong bearer and the engine answered 400.
  if [ -n "$RODD_RESOLVED_KEY" ]; then hk="$RODD_RESOLVED_KEY"; else hk="$(head_key || true)"; fi
  # THE DESK STAYS WHOLE (plan 271, the Allfather 2026-11-12: "it needs to work if I'm in Discord also").
  # Two separate facts, kept apart:
  #  1. The `serve` road opens NO microphone — Rödd's window captures through the browser and the sound
  #     server shares the device — so a held mic is no reason to refuse the engine itself (the 2026-11-09
  #     refusal belongs to the `talk` road, which does open the device; see cmd_client).
  #  2. A dev seat's display GPU is not the engine's: on a dev seat Kokoro and the ear run on the CPU,
  #     whatever was asked (the same pin as kokoro-serve), so the engine cannot disturb a call's browser.
  # What the helm may not do is START things at the operator's desk during a call: the guard is asked,
  # and only the operator's explicit --now (Rödd's own start and restart pass it) goes through.
  "$ROOT/bin/desk/in-call.sh" check $([ "$DO_NOW" = 1 ] && echo --now) --what "the voice engine" || return 3
  local desk_role; desk_role="$("$ROOT/bin/desk/in-call.sh" role 2>/dev/null | head -1)"
  local -a engine_pin=()
  # The machine's own choice comes first (plan 275, 2026-11-12): ~/.config/ymir/voice.env is per machine, never the
  # shared home, because one machine has a free compute GPU and another has none. YMIR_VOICE_GPU=on puts the ear and
  # the voice on the GPU: on heimdall the RTX A5000 sat at 0 % while Kokoro on the CPU took 28 s to its first word.
  # The Allfather: "It was much faster with the voice back before."
  local _vgpu="${YMIR_VOICE_GPU:-}"
  [ -n "$_vgpu" ] || _vgpu="$(sed -n 's/^[[:space:]]*YMIR_VOICE_GPU[[:space:]]*=[[:space:]]*//p' "${XDG_CONFIG_HOME:-$HOME/.config}/ymir/voice.env" 2>/dev/null | tail -1 | tr -d "\"'")"
  if [ "$_vgpu" = on ] && command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
    STT_DEVICE=cuda; STT_COMPUTE=float16
    engine_pin=(--device cuda)
    unset CUDA_VISIBLE_DEVICES
    say "voice on the GPU (YMIR_VOICE_GPU=on for this machine)"
  elif [ "$desk_role" = dev ]; then
    STT_DEVICE=cpu; STT_COMPUTE=int8
    engine_pin=(--device cpu)
    CUDA_VISIBLE_DEVICES=""
  fi
  local cu; cu="$(cuda_lib_path || true)"
  # YMIR_VOICE_DRY=1 prints what would be raised and changes nothing (the tests, and a look before a leap)
  if [ "${YMIR_VOICE_DRY:-0}" = 1 ]; then
    build_host_argv
    say "dry: would raise $UNIT: $eng serve ${engine_pin[*]:-} stt_device=$STT_DEVICE CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES-<unset>}"
    return 0
  fi
  mkdir -p "$STATE_DIR"
  if [ "${RODD_HEAD_MODE_RESOLVED:-local}" = "online" ]; then
    raise_head_proxy || err "warning: the head proxy did not answer on $PROXY_PORT — the head may refuse"
  fi
  systemctl --user stop "$UNIT" 2>/dev/null || true
  # shellcheck disable=SC2046
  build_host_argv
  systemd-run --user --unit="$UNIT" --collect \
    --setenv=VIRTUAL_ENV="$VENV" \
    --setenv=PATH="$VENV/bin:/usr/local/bin:/usr/bin:/bin" \
    --setenv=HF_HUB_DISABLE_XET=1 \
    --setenv=HF_HUB_OFFLINE=1 \
    ${CUDA_VISIBLE_DEVICES+--setenv=CUDA_VISIBLE_DEVICES="$CUDA_VISIBLE_DEVICES"} \
    ${cu:+--setenv=LD_LIBRARY_PATH="$cu"} \
    --property=StandardOutput=append:"$STATE_DIR/host.log" \
    --property=StandardError=append:"$STATE_DIR/host.log" \
    "$eng" serve "${HOST_ARGV[@]}" "${engine_pin[@]}" ${hk:+--responses_api_api_key "$hk"} >/dev/null || {
      err "error: could not raise $UNIT"; return 1; }
  printf '%s\n' "$(date -Is) unit=$UNIT port=$PORT head=$HEAD_URL/$HEAD_MODEL" >> "$STATE_DIR/host.seat"
  # THE CARD IS BORROWED, NOT KEPT (plan 275 item 23). Raise the idle watcher beside the
  # engine: after YMIR_VOICE_IDLE_SECONDS with no session in use it stops the engine and the
  # card is free for the rail. It is best-effort by design — an engine that runs and never
  # lets go is worse, but a missing watcher must not stop the voice from working.
  if [ "${YMIR_VOICE_IDLE_SECONDS:-300}" != 0 ] && command -v systemd-run >/dev/null 2>&1; then
    systemctl --user stop "$IDLE_UNIT" 2>/dev/null || true
    systemd-run --user --unit="$IDLE_UNIT" --collect \
      --property=StandardOutput=append:"$STATE_DIR/idle.log" \
      --property=StandardError=append:"$STATE_DIR/idle.log" \
      --setenv=YMIR_VOICE_PORT="$PORT" \
      --setenv=YMIR_VOICE_IDLE_SECONDS="${YMIR_VOICE_IDLE_SECONDS:-300}" \
      "$ROOT/bin/voice/voice-idle.sh" watch >/dev/null 2>&1 \
      || err "warning: the idle watcher did not start — the engine will hold the card until it is stopped"
  fi
  for _ in $(seq 1 90); do host_answers && { say "host up on 127.0.0.1:$PORT (log: $STATE_DIR/host.log)"; return 0; }; sleep 1; done
  err "error: $UNIT started but nothing answers on $PORT yet — read $STATE_DIR/host.log"
  return 1
}

cmd_client() {
  local eng host
  eng="$(find_engine || true)"
  [ -n "$eng" ] || { err "error: the engine is absent; run: bin/voice/voice-door.sh --install"; return 1; }
  # The `talk` road DOES open a capture device, so it keeps the refusal a call earns — and it never flips a
  # Bluetooth headset's profile behind the operator's back: opening a capture stream on a headset in A2DP
  # drops the call's audio (plan 271). Asked of the one door; the operator's --now is the only way past.
  if [ "$DO_NOW" != 1 ]; then
    "$ROOT/bin/desk/in-call.sh" check --what "the voice client (it opens the microphone)" || return 3
    if "$ROOT/bin/desk/in-call.sh" bluetooth 2>/dev/null; then
      err "refused: the active microphone is a Bluetooth headset — opening it here would flip its profile and drop the headset's audio"
      err "hint: use the machine's own microphone (set YMIR_VOICE_INPUT_DEVICE), or pass --now"
      return 3
    fi
  fi
  host="$(resolve_host || true)"
  [ -n "$host" ] || { err "error: no host seat reachable — set YMIR_VOICE_HOST, or run 'host' here"; return 1; }
  if [ "$host" != "$(hostname -s)" ]; then
    if ! host_answers; then
      ssh -f -N -o ExitOnForwardFailure=yes -L "$PORT:127.0.0.1:$PORT" "$host" || {
        err "error: could not open the tunnel to the host seat"; return 1; }
      say "tunnel open: local $PORT → the host's own loopback"
    fi
  fi
  local -a argv=("$eng" talk --url "ws://127.0.0.1:$PORT/v1/realtime" --log-transcripts)
  local -a extra=()
  # half-duplex by default (see the header): the speakers and the microphone share one room
  [ "$BARGE_IN" = 1 ] || extra+=(--block-mic-during-playback)
  # capture from the source the operator names, never a surprise default
  [ -n "${YMIR_VOICE_INPUT_DEVICE:-}" ] && extra+=(--input-device "$YMIR_VOICE_INPUT_DEVICE")
  # the hands: a tool module, importable from the repo's voice shelf
  if [ "$TOOLS_ON" = 1 ] && [ -r "$ROOT/bin/voice/voice_tools.py" ]; then
    # carried ON the command, not in this shell's env: a herdr pane does not inherit it
    argv=(env "PYTHONPATH=$ROOT/bin/voice${PYTHONPATH:+:$PYTHONPATH}" "${argv[@]}")
    extra+=(--tool-module voice_tools)
  fi
  # a herdr pane is preferred: the voice sits beside the work, not in a stray window
  export YMIR_VOICE_HOST_SEAT="$host" YMIR_VOICE_CHAT_SIZE="$CHAT_SIZE"
  if [ "$PANE" = 1 ] && [ -x "$ROOT/bin/seat/herdr-run.sh" ] \
     && "$ROOT/bin/seat/herdr-run.sh" available >/dev/null 2>&1; then
    say "seating the voice in a herdr pane"
    exec "$ROOT/bin/seat/herdr-run.sh" run voice -- "${argv[@]}" "${extra[@]}" "$@"
  fi
  exec "${argv[@]}" "${extra[@]}" "$@"
}

cmd_install() {
  [ "$DO_INSTALL" = 1 ] || { err "this installs software; re-run with --install to confirm"; return 2; }
  have uv || { err "error: uv is required (the engine lives in its own venv, never a system python)"; return 1; }
  uv venv --python 3.12 "$VENV" && uv pip install --python "$VENV/bin/python" "speech-to-speech[faster-whisper,kokoro]" || return 1
  say "installed into $VENV — nothing was installed into a system python, a pi tool env, or kokoro-cli's env"
}

# --- the two verbs the operator actually uses ---------------------------------

close_stale_voice_tabs() {
  command -v herdr >/dev/null 2>&1 || return 0
  [ "${HERDR_ENV:-}" = 1 ] || return 0
  herdr tab list 2>/dev/null | python3 -c '
import json,sys
try: data=json.load(sys.stdin)["result"]["tabs"]
except Exception: raise SystemExit(0)
for t in data:
    label=(t.get("label") or "")
    if label.startswith("Rödd") or label.endswith(":voice"):
        print(t["tab_id"])
' 2>/dev/null | while read -r tab; do [ -n "$tab" ] && herdr tab close "$tab" >/dev/null 2>&1; done
}

cmd_start() {
  local eng host
  eng="$(find_engine || true)"
  [ -n "$eng" ] || { err "error: the engine is absent; run: bin/voice/voice-door.sh --install"; return 1; }
  close_stale_voice_tabs
  host="$(resolve_host || true)"
  [ -n "$host" ] || { err "error: no seat can host yet — set YMIR_VOICE_HOST, then run 'host' there"; return 1; }
  if [ "$host" = "$(hostname -s)" ] || [ "$host" = localhost ]; then
    cmd_host || return 1
  elif ! host_answers_on "$host"; then
    say "raising the pipeline on the host seat…"
    ssh -o BatchMode=yes "$host" \
      "cd ~/ymir && YMIR_VOICE_HEAD_MODEL='${HEAD_MODEL}' YMIR_VOICE_STT_DEVICE='${STT_DEVICE}' YMIR_VOICE_STT_COMPUTE='${STT_COMPUTE}' ./bin/voice/voice-door.sh host" 2>&1 | tail -2
  fi
  cmd_client "$@"
}

cmd_stop() {
  local host
  for p in $(pgrep -f 'speech-to-speech[ ]talk' 2>/dev/null); do kill "$p" 2>/dev/null; done
  for t in $(pgrep -f "ssh [^ ]*-L $PORT:127.0.0.1:$PORT" 2>/dev/null); do kill "$t" 2>/dev/null; done
  say "client and tunnel lowered here"
  if [ "$DO_STOP" = 1 ]; then
    host="$(resolve_host || true)"
    if [ -n "$host" ] && [ "$host" != "$(hostname -s)" ]; then
      ssh -o BatchMode=yes "$host" "cd ~/ymir && ./bin/voice/voice-door.sh host --stop" 2>&1 | tail -1
    else
      systemctl --user stop "$IDLE_UNIT" 2>/dev/null || true
      systemctl --user stop "$UNIT" 2>/dev/null && say "pipeline lowered here" || say "no pipeline was running here"
    fi
  else
    say "the pipeline stays up on the host seat (lower it with: voice-door.sh stop --host)"
  fi
}

cmd_log() {
  local lines="${1:-40}" host dir
  host="$(resolve_host || true)"
  dir="${YMIR_HOME:?the home is resolved at the top of this door}/hodd/state/voice"
  printf 'voice_activity[%s]{when,event,detail}:\n' "$(date -Is)"
  if ls "$dir"/activity-*.jsonl >/dev/null 2>&1; then
    python3 - "$dir" "$lines" <<'PY'
import glob, json, sys
dir_, n = sys.argv[1], int(sys.argv[2])
rows = []
for f in sorted(glob.glob(dir_ + "/activity-*.jsonl"))[-2:]:
    for line in open(f, encoding="utf-8", errors="ignore"):
        try: rows.append(json.loads(line))
        except Exception: pass
for r in rows[-n:]:
    detail = r.get("output") or r.get("error") or json.dumps(r.get("args", {}), ensure_ascii=False)
    print(f'  "{r.get("ts","")}","{r.get("event","")}","{r.get("tool","")} {str(detail)[:120]}"')
PY
  else
    printf '  "%s","none","no tool has been used yet"\n' "$(date -Is)"
  fi
  if [ -n "$host" ]; then
    printf '# turns, from the host seat log:\n'
    timeout 12 ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" \
      'h=$(bash -lc '. ~/ymir/bin/vault/hoard-lib.sh >/dev/null 2>&1; ymir_home_root YMIR_HOME >/dev/null 2>&1; printf %s "$YMIR_HOME"' 2>/dev/null); d="$h/hodd/state/voice/host.log"; tail -n 800 "$d" 2>/dev/null | grep -E "USER:|ASSISTANT:|latency:" | tail -n '"$lines" 2>/dev/null | cut -c1-160
  fi
}

case "$CMD" in
  status)  cmd_status ;;
  which-host) resolve_host ;;   # the ONE answer to "where does the engine live" (Rödd asks this, plan 275)
  plan)    cmd_plan ;;
  host)    cmd_host ;;
  client)  cmd_client "$@" ;;
  start)   cmd_start "$@" ;;
  stop)    cmd_stop ;;
  log)     cmd_log "${1:-40}" ;;
  --install) cmd_install ;;
esac
