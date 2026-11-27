#!/usr/bin/env bash
# kokoro-lib.sh — where the Kokoro speech engine listens: ONE value, read by the unit and every client
# (plan 326.0, Rule 07).
#
# The value is KOKORO_SERVICE_URL, the engine's own name for it (`kokoro speak` and `kokoro doctor` read it).
# It is resolved, in order:
#
#   1. the environment                       (a one-off run overrides without editing anything)
#   2. $YMIR_HOME/config/voice.env           (the operator's answer; template: config/voice.env.example)
#   3. the documented default below          (the engine's own `kokoro serve` default — the only copy in Ymir)
#
# Sourced:   . bin/voice/kokoro-lib.sh; kokoro_base_url; kokoro_speech_url; kokoro_port
# Run:       bin/voice/kokoro-lib.sh [base|speech|port|env]
#
# A client that still sets KOKORO_URL keeps it: that is an explicit override of the speech endpoint, and
# kokoro_speech_url honours it. The unit (kokoro-serve.service) reads the same voice.env through its
# EnvironmentFile and binds kokoro_port — so the port a client dials and the port the engine binds come from
# one line. Loopback only: the engine refuses any other host, and so does this resolver.

KOKORO_DEFAULT_SERVICE_URL="http://127.0.0.1:8765"   # the engine's own default (kokoro_cli serve --port 8765)

_kokoro_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_kokoro_env_file() {  # the operator's voice.env, or nothing
  local home="${YMIR_HOME:-}"
  if [ -z "$home" ] && [ -r "$_kokoro_lib_dir/../vault/hoard-lib.sh" ]; then
    # shellcheck source=../vault/hoard-lib.sh
    . "$_kokoro_lib_dir/../vault/hoard-lib.sh" 2>/dev/null && ymir_home_root home 2>/dev/null
  fi
  [ -n "$home" ] && [ -r "$home/config/voice.env" ] && printf '%s\n' "$home/config/voice.env"
}

kokoro_base_url() {  # prints the base URL (no path), loopback only
  local url="${KOKORO_SERVICE_URL:-}" file line
  if [ -z "$url" ]; then
    file="$(_kokoro_env_file)"
    if [ -n "$file" ]; then
      line="$(grep -E '^[[:space:]]*KOKORO_SERVICE_URL=' "$file" | tail -1)"
      url="${line#*=}"; url="${url%\"}"; url="${url#\"}"; url="${url%\'}"; url="${url#\'}"
    fi
  fi
  url="${url:-$KOKORO_DEFAULT_SERVICE_URL}"
  url="${url%/}"
  case "$url" in
    http://127.0.0.1:*|http://localhost:*|"http://[::1]:"*) ;;
    *) printf 'kokoro-lib: KOKORO_SERVICE_URL must be http on loopback with a port, got %s\n' "$url" >&2; return 1 ;;
  esac
  printf '%s\n' "$url"
}

kokoro_port() {  # the port alone — what the unit binds
  local url; url="$(kokoro_base_url)" || return 1
  url="${url##*:}"; printf '%s\n' "${url%%/*}"
}

kokoro_speech_url() {  # the OpenAI-style speech endpoint; an explicit KOKORO_URL wins
  if [ -n "${KOKORO_URL:-}" ]; then
    case "$KOKORO_URL" in
      */v1/audio/speech) printf '%s\n' "$KOKORO_URL" ;;
      *) printf '%s/v1/audio/speech\n' "${KOKORO_URL%/}" ;;
    esac
    return 0
  fi
  local base; base="$(kokoro_base_url)" || return 1
  printf '%s/v1/audio/speech\n' "$base"
}

kokoro_port_squatter() {  # says who holds the engine's port when it is NOT kokoro-serve; prints nothing otherwise
  local port line pid main
  port="$(kokoro_port)" || return 0
  command -v ss >/dev/null 2>&1 || return 0
  line="$(ss -Hltnp "sport = :$port" 2>/dev/null | head -1)"
  pid="$(printf '%s' "$line" | sed -n 's/.*pid=\([0-9]*\).*/\1/p')"
  [ -n "$pid" ] || return 0
  main="$(systemctl --user show -p MainPID --value kokoro-serve.service 2>/dev/null)"
  [ "$pid" = "$main" ] && return 0
  case "$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)" in *kokoro*) return 0 ;; esac
  printf 'port %s is held by another program, pid %s (%s) — stop it, then: systemctl --user restart kokoro-serve\n' \
    "$port" "$pid" "$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | sed 's/ *$//' | cut -c1-80)"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-base}" in
    base) kokoro_base_url ;;
    speech) kokoro_speech_url ;;
    port) kokoro_port ;;
    env) f="$(_kokoro_env_file)"; printf 'KOKORO_SERVICE_URL=%s\nfrom=%s\n' "$(kokoro_base_url)" \
           "$( [ -n "${KOKORO_SERVICE_URL:-}" ] && echo environment || { [ -n "$f" ] && echo "$f" || echo default; })" ;;
    -h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//' ;;
    *) printf 'usage: kokoro-lib.sh [base|speech|port|env]\n' >&2; exit 2 ;;
  esac
fi
