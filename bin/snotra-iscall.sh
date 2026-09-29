#!/usr/bin/env bash
# snotra-iscall.sh — is a real call in progress on this seat?
#
# WHY THIS EXISTS
# The watch (bin/snotra-detect.sh) must never treat "an application opened the
# microphone" as a meeting. A browser tab, a dictation daemon, a test harness, the
# ear's own capture and a stray Discord connection all take the mic with nobody in
# a call — and on 2026-09-28 that fired the watch repeatedly on a seat where no
# meeting existed, recording the room and announcing it again and again.
#
# The discriminator is the stream's **`media.role`**, the property the sound
# server's clients set while a call is live (PulseAudio's `Communication`, which
# PipeWire's session manager surfaces as `phone`). A bare mic grab carries no
# `media.role` at all. Measured on heimdall 2026-09-28: an idle Chromium mic hold
# reports `application.name = "Chromium input"`, `application.process.binary =
# "chromium"` and **no `media.role`**; a stream created with
# `--property=media.role=Communication` reports `media.role = "phone"`.
#
# Exit status: 0 = a call IS in progress (arm the ear), 1 = no call.
#
# Usage:
#   snotra-iscall.sh            # the verdict, exit 0/1
#   snotra-iscall.sh --why      # one line: the reason, for the log
#   snotra-iscall.sh --json     # {"call":bool,"reason":...,"app":...,"role":...}
#
# Env (Rule 07: env -> recorded choice -> one documented default):
#   YMIR_HOME / YMIR_STATE_DIR   where the explicit arm marker lives
#   SNOTRA_ARM_MARKER            explicit arm marker (default <state>/.snotra-arm)
#   SNOTRA_CALL_ROLES            role values that mean a call
#                                (default "communication phone")
#   SNOTRA_IGNORE_BINARIES       extra binaries that are NEVER a call
#   SNOTRA_ISCALL_FIXTURE        read the sound server's JSON from this file
#                                instead of asking it live (the tests' seam)

set -u

# The operator's home, resolved by the ONE resolver (bin/hoard-lib.sh) — env →
# recorded → documented default. It was `${YMIR_HOME:-$HOME/Documents/ymirhome}`,
# which is one machine's layout, and the defaults-guard refuses it.
# shellcheck disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hoard-lib.sh" 2>/dev/null || true
if command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi
STATE_DIR="${YMIR_STATE_DIR:-${YMIR_HOME}/state}"
ARM_MARKER="${SNOTRA_ARM_MARKER:-$STATE_DIR/.snotra-arm}"
CALL_ROLES="${SNOTRA_CALL_ROLES:-communication phone}"

# The house's own audio tools — anything that takes the mic as a *tool*, never a
# caller. An app that is genuinely in a call is not on this list.
DEFAULT_IGNORE="ffmpeg ffplay parec pacat arecord aplay pw-record pw-cat sox rec \
whisper-cli whisper-cpp whisper whisper-server python python3 bash sh dash zsh \
snotra-capture snotra-transcribe snotra-detect voxtype"

is_ignored() {  # <binary>
  local b="${1:-}" x
  [ -n "$b" ] || return 1
  for x in $DEFAULT_IGNORE ${SNOTRA_IGNORE_BINARIES:-}; do
    [ "$b" = "$x" ] && return 0
  done
  return 1
}

role_is_call() {  # <role>
  local r
  r="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  local want
  for want in $CALL_ROLES; do
    [ "$r" = "$want" ] && return 0
  done
  return 1
}

# streams_json — prints the sound server's source-outputs as JSON.
streams_json() {
  if [ -n "${SNOTRA_ISCALL_FIXTURE:-}" ]; then
    [ -r "$SNOTRA_ISCALL_FIXTURE" ] && cat "$SNOTRA_ISCALL_FIXTURE"
    return 0
  fi
  command -v pactl >/dev/null 2>&1 || return 1
  pactl --format=json list source-outputs 2>/dev/null
}

# The verdict. Prints "<call>\t<reason>\t<app>\t<role>" and returns 0 when a call
# is live. One place decides, so the watch, the tests and any future caller agree.
verdict() {
  local json app role bin token first_call=""

  # 1. An explicit arm outranks the heuristic: the Þing door (the room knows a
  #    meeting began) and the operator's own hand both write this marker.
  if [ -e "$ARM_MARKER" ]; then
    printf '1\texplicit arm (%s)\t-\t-\n' "$ARM_MARKER"
    return 0
  fi

  json="$(streams_json || true)"
  if [ -z "$json" ]; then
    printf '0\tno sound server answered\t-\t-\n'
    return 1
  fi

  while IFS=$'\t' read -r app bin role; do
    [ -n "$app$bin$role" ] || continue
    role_is_call "$role" || continue
    case " $DEFAULT_IGNORE ${SNOTRA_IGNORE_BINARIES:-} " in
      *" $bin "*) continue ;;
    esac
    printf '1\t%s is in a call (media.role=%s)\t%s\t%s\n' "${bin:-$app}" "$role" "${app:-$bin}" "$role"
    return 0
  done <<EOF
$(printf '%s' "$json" | python3 -c '
import json,sys
try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
if not isinstance(data, list):
    raise SystemExit(0)
for st in data:
    p = st.get("properties") or {}
    app = p.get("application.name") or ""
    bin_ = p.get("application.process.binary") or ""
    role = p.get("media.role") or ""
    if not (app or bin_ or role):
        continue
    print("%s\t%s\t%s" % (app, bin_, role))
' 2>/dev/null)
EOF
  printf '0\tno stream carries a call role (%s)\t-\t-\n' "$CALL_ROLES"
  return 1
}

case "${1:-}" in
  -h|--help)
    sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0 ;;
esac

line="$(verdict)"; rc=$?
call="${line%%$'\t'*}"; rest="${line#*$'\t'}"
reason="${rest%%$'\t'*}"; rest="${rest#*$'\t'}"
app="${rest%%$'\t'*}"; role="${rest#*$'\t'}"

case "${1:-}" in
  --json)
    python3 -c 'import json,sys;print(json.dumps({"call":sys.argv[1]=="1","reason":sys.argv[2],"app":sys.argv[3],"role":sys.argv[4]}))' \
      "$call" "$reason" "$app" "$role" ;;
  --why) printf '%s\n' "$reason" ;;
  *)     [ "$call" = "1" ] && printf '%s\n' "$reason" ;;
esac
exit $rc
