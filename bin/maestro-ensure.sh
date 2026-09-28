#!/usr/bin/env bash
# maestro-ensure.sh — the video forge's provision seam (Maestro).
#
# Maestro is the local AI video forge: a FastAPI server that serves a UI and a
# full REST API on one port. This script is the SEAM between the public skill
# (.agents/skills/maestro-video/) and a seat: it detects whether the box may
# carry a forge at all, renders the systemd user unit, seats it on ymir.target,
# and proves the door answers.
#
# THE COMPUTE BOUNDARY COMES FIRST (plan 51 Part 9a): a weak seat never runs
# inference — it calls the lane. So `detect` is a hard gate, and `ensure`
# REFUSES on a box with no usable CUDA device rather than installing a forge
# that cannot generate. A loud refusal, never a silent skip.
#
# Usage:
#   maestro-ensure.sh status            # door + GPU + unit truth (TOON)
#   maestro-ensure.sh detect            # the GPU gate alone (exit 1 if unfit)
#   maestro-ensure.sh ensure            # render + seat the unit + verify
#   maestro-ensure.sh verify            # the proof alone (non-zero on gaps)
#   maestro-ensure.sh --version | --help
#
# Env: MAESTRO_URL (default http://127.0.0.1:7860)
#      MAESTRO_APP_DIR · MAESTRO_PORT · MAESTRO_LLAMA_BIN · MAESTRO_UNIT_DIR
#      BROKK_ROOT_OVERRIDE (the tree that ships the unit template)
# Exit: 0 ok · 1 unfit/gap · 2 usage.
set -u

VERSION="1.0.0"
URL="${MAESTRO_URL:-http://127.0.0.1:7860}"
PORT="${MAESTRO_PORT:-7860}"
APP_DIR="${MAESTRO_APP_DIR:-$HOME/CodeP/MaestroAiVideo/app}"
LLAMA_BIN="${MAESTRO_LLAMA_BIN:-/usr/local/bin}"
UNIT_DIR="${MAESTRO_UNIT_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user}"
UNIT="maestro.service"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
CMD="${1-}"; shift || true
DO_INSTALL=0
while [ $# -gt 0 ]; do
  case "$1" in --install) DO_INSTALL=1; shift ;; *) shift ;; esac
done

case "$CMD" in
  status|detect|ensure|verify) ;;
  *) printf 'error: unknown command %s\nhelp: bin/maestro-ensure.sh [status|detect|ensure|verify]\n' "$CMD" >&2; exit 2 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
TEMPLATE="$ROOT/.agents/skills/maestro-video/assets/maestro.service"

say() { printf '%s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

# --- the door ---------------------------------------------------------------
door_up() { have curl && curl -sf --max-time 4 "$URL/api/v1/models" >/dev/null 2>&1; }

door_models() {
  curl -s --max-time 10 "$URL/api/v1/models" 2>/dev/null | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(1)
ms=d.get("models",[])
dl=[m["model_type"] for m in ms if m.get("is_downloaded")]
ids=",".join(dl[:6]) or "-"
print("%d\t%d\t%d\t%s" % (len(d.get("families",[])), len(ms), len(dl), ids))' 2>/dev/null
}

# --- the gate (plan 51 Part 9a) --------------------------------------------
# Prints: cuda|name|vram_mib|compute_cap   (empty when no NVIDIA device)
gpu_probe() {
  have nvidia-smi || return 1
  nvidia-smi --query-gpu=name,memory.total,compute_cap --format=csv,noheader,nounits 2>/dev/null | head -n1
}

gpu_fit() {  # <name,total_mib,cap>  -> 0 fit / 1 unfit (message on stderr)
  local line="$1" name total cap
  name="$(printf '%s' "$line" | awk -F', *' '{print $1}')"
  total="$(printf '%s' "$line" | awk -F', *' '{print $2}')"
  cap="$(printf '%s' "$line" | awk -F', *' '{print $3}')"
  local major="${cap%%.*}" vram_gb
  vram_gb=$(( total / 1024 ))
  if [ -z "$major" ] || [ "$major" -lt 8 ] 2>/dev/null; then
    say "maestro: UNFIT — $name reports compute capability ${cap:-unknown}."
    say "maestro:   the forge needs sm_80 or newer. This seat calls the lane instead (plan 51 Part 9a)."
    return 1
  fi
  if [ "$vram_gb" -lt 12 ] 2>/dev/null; then
    say "maestro: UNFIT — $name has ${vram_gb} GiB VRAM."
    say "maestro:   a video family plus its text encoder needs ~12 GiB minimum. Call the lane instead."
    return 1
  fi
  return 0
}

llama_cuda_ok() {  # <dir> -> 0 when it holds a CUDA llama-server
  [ -x "$LLAMA_BIN/llama-server" ] || return 1
  "$LLAMA_BIN/llama-server" --list-devices 2>/dev/null | grep -q CUDA
}

status() {
  local u="false" g="none" m="— — — —" d="false"
  door_up && d="true"
  g="$(gpu_probe || true)"; [ -n "$g" ] || g="none"
  if have systemctl; then systemctl --user is-active --quiet "$UNIT" 2>/dev/null && u="true"; fi
  [ "$d" = "true" ] && m="$(door_models || printf '%s' "— — — —")"
  local fam md dl dls
  fam="$(printf '%s' "$m" | cut -f1)"; md="$(printf '%s' "$m" | cut -f2)"
  dl="$(printf '%s' "$m" | cut -f3)"; dls="$(printf '%s' "$m" | cut -f4)"
  printf 'maestro[4]{door_url,door_up,unit_active,gpu}:\n'
  printf '  "%s","%s","%s","%s"\n' "$URL" "$d" "$u" "${g%%,*}"
  printf 'maestro_models[4]{families,model_types,downloaded,downloaded_ids}:\n'
  printf '  "%s","%s","%s","%s"\n' "${fam:-—}" "${md:-—}" "${dl:-—}" "${dls:-—}"
  [ "$d" = "true" ] && return 0
  return 1
}

detect() {
  local g
  if ! g="$(gpu_probe)"; then
    say "maestro: UNFIT — no NVIDIA device (nvidia-smi absent or reports none)."
    say "maestro:   a CPU-only seat is a caller, not a forge (plan 51 Part 9a)."
    printf 'maestro_gate[3]{fit,device,vram}:\n'
    printf '  "false","none","—"\n'
    return 1
  fi
  local name total cap
  name="$(printf '%s' "$g" | awk -F', *' '{print $1}')"
  total="$(printf '%s' "$g" | awk -F', *' '{print $2}')"
  cap="$(printf '%s' "$g" | awk -F', *' '{print $3}')"
  local fit="true" note="cuda"
  gpu_fit "$g" || fit="false"
  [ "$fit" = "true" ] || note="unfit"
  printf 'maestro_gate[4]{fit,device,compute_cap,vram_mib}:\n'
  printf '  "%s","%s","%s","%s"\n' "$fit" "$name" "$cap" "$total"
  [ "$fit" = "true" ]
}

render_unit() {
  [ -f "$TEMPLATE" ] || { say "maestro: no unit template at $TEMPLATE"; return 1; }
  # Render the seat's real paths into the template. A tree under $HOME keeps the
  # %h form (systemd expands it per user); a tree elsewhere goes in absolute —
  # ${APP_DIR#$HOME/} on an outside path leaves a leading slash and renders a
  # bogus `%h//tmp/app` (a real fault, caught in test).
  local app_rendered="$APP_DIR"
  case "$APP_DIR" in "$HOME"/*) app_rendered="%h/${APP_DIR#"$HOME"/}" ;; esac
  # Escape the values for sed: backslash, the & (whole-match) and our '|' delimiter.
  local app_sed="$app_rendered" llama_sed="$LLAMA_BIN"
  app_sed="${app_sed//\\/\\\\}"; app_sed="${app_sed//&/\\&}"; app_sed="${app_sed//|/\\|}"
  llama_sed="${llama_sed//\\/\\\\}"; llama_sed="${llama_sed//&/\\&}"; llama_sed="${llama_sed//|/\\|}"
  sed -e "s|%h/CodeP/MaestroAiVideo/app|${app_sed}|g" \
      -e "s|^Environment=MAESTRO_LLAMA_BIN=.*|Environment=MAESTRO_LLAMA_BIN=${llama_sed}|" \
      -e "s|^Environment=SERVER_PORT=.*|Environment=SERVER_PORT=${PORT}|" \
      "$TEMPLATE"
}

ensure() {
  say "maestro: ensuring the video forge on this seat"
  detect || { say "maestro: REFUSED — the gate failed; nothing was changed."; return 1; }
  [ -d "$APP_DIR" ] || {
    if [ "$DO_INSTALL" = "1" ]; then
      say "maestro: app tree absent at $APP_DIR — the install is a Pinokio app reproduced by hand."
      say "maestro:   follow assets/setup-for-users.md (§2). Refusing to guess an install."
    else
      say "maestro: app tree absent at $APP_DIR."
      say "maestro:   run with --install after reading assets/setup-for-users.md §2, or set MAESTRO_APP_DIR."
    fi
    return 1
  }
  [ -x "$APP_DIR/env/bin/python" ] || {
    say "maestro: no python venv at $APP_DIR/env — the install is incomplete."
    say "maestro:   see assets/setup-for-users.md §2."
    return 1
  }
  llama_cuda_ok || {
    say "maestro: REFUSED — $LLAMA_BIN holds no CUDA llama-server."
    say "maestro:   without one the planner COMPILES llama.cpp from source (~15 min, usually fails)."
    say "maestro:   set MAESTRO_LLAMA_BIN to a directory that holds a CUDA build, or run bin/llama-ensure.sh."
    return 1
  }
  # A door already answering is adopted, never fought.
  if door_up; then
    say "maestro: door already answers at $URL — adopted, not restarted"
    verify && return 0
  fi
  have systemctl || { say "maestro: no systemctl; seat the unit by hand (assets/maestro.service)"; return 1; }
  mkdir -p "$UNIT_DIR" "$HOME/.fleet"
  render_unit >"$UNIT_DIR/$UNIT" || return 1
  systemctl --user daemon-reload || return 1
  systemctl --user enable --now "$UNIT" || { say "maestro: failed to seat $UNIT"; return 1; }
  say "maestro: unit seated ($UNIT on ymir.target); waiting for the door…"
  local i=0 wait_secs="${MAESTRO_WAIT_SECS:-300}"
  while [ "$i" -lt "$wait_secs" ]; do
    door_up && break
    sleep 5; i=$((i+5))
  done
  verify
}

verify() {
  local rc=0
  if door_up; then
    say "maestro: door UP at $URL"
  else
    say "maestro: door DOWN at $URL"
    rc=1
  fi
  if have systemctl && ! systemctl --user is-active --quiet "$UNIT" 2>/dev/null; then
    say "maestro: note — unit $UNIT is not active (a forge may be running outside it)"
  fi
  local pf
  pf="$(curl -s --max-time 10 "$URL/api/v1/system/preflight" 2>/dev/null)"
  case "$pf" in
    *'"ok":true'*) say "maestro: preflight OK" ;;
    '') : ;;
    *) say "maestro: preflight reports a problem: $pf"; rc=1 ;;
  esac
  [ "$rc" = "0" ] && printf 'maestro_proof[1]{door,preflight}:\n  "up","ok"\n'
  return "$rc"
}

case "$CMD" in
  status) status ;;
  detect) detect ;;
  ensure) ensure ;;
  verify) verify ;;
esac
