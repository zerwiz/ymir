#!/usr/bin/env bash
# snotra-voice-device.sh — the virtual microphone a meeting can hear Snotra through.
#
# Creates a PipeWire null sink and remaps its monitor to a source called
# "Snotra Mic". A meeting client selects that source as its microphone; audio
# played into the sink goes into the meeting's uplink.
#
#   snotra-voice-device.sh ensure|status|remove|test
#
# Env: SNOTRA_MIC_NAME (default snotra_mic)
set -u
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-status}"
NAME="${SNOTRA_MIC_NAME:-snotra_mic}"
ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; s="$d"; while [ "$d" != / ] && { [ ! -d "$d/RULES" ] || [ ! -d "$d/.agents" ]; }; do d="$(dirname "$d")"; done; { [ -d "$d/RULES" ] && [ -d "$d/.agents" ]; } || d="$s"; printf '%s' "$d")"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true; fi
YMIR_HOME="${YMIR_HOME:-}"; [ -n "$YMIR_HOME" ] || ymir_home_root YMIR_HOME 2>/dev/null || true
STATE="${YMIR_HOME:-$HOME}/hodd/state/snotra/voice-device.json"
mkdir -p "$(dirname "$STATE")"
die(){ printf 'error: %s\n' "$*" >&2; exit 1; }
command -v pactl >/dev/null || die "pactl not found"

sink_exists(){ pactl list short sinks 2>/dev/null | awk '{print $2}' | grep -qx "$NAME"; }
source_exists(){ pactl list short sources 2>/dev/null | awk '{print $2}' | grep -qx "$NAME"; }

ensure(){
  local ids=""
  if ! sink_exists; then
    local id; id="$(pactl load-module module-null-sink sink_name="$NAME" \
      sink_properties=device.description="Snotra Mic Sink" 2>/dev/null)" || die "null sink failed"
    ids="$ids $id"
  fi
  if ! source_exists; then
    local id; id="$(pactl load-module module-remap-source master="$NAME.monitor" source_name="$NAME" \
      source_properties=device.description="Snotra Mic" 2>/dev/null)" || die "remap source failed"
    ids="$ids $id"
  fi
  python3 - "$STATE" "$NAME" "$ids" <<'PY'
import json,sys
p,name,ids=sys.argv[1:]
try: d=json.load(open(p))
except Exception: d={"modules":[]}
d["name"]=name
d["modules"]=list(dict.fromkeys(d.get("modules",[])+[x for x in ids.split() if x]))
json.dump(d,open(p,"w"),indent=2)
PY
  printf 'device\t%s\t%s\n' "$NAME" "$(source_exists && echo ready || echo missing)"
}
status(){
  local s=no r=no; sink_exists && s=yes; source_exists && r=yes
  printf 'voice_device[1]{name,sink,source}:\n  "%s","%s","%s"\n' "$NAME" "$s" "$r"
  [ "$s" = yes ] && [ "$r" = yes ] || return 1
}
remove(){
  local m; for m in $(python3 -c "import json;print(' '.join(json.load(open('$STATE')).get('modules',[])))" 2>/dev/null); do
    pactl unload-module "$m" 2>/dev/null || true
  done
  sink_exists && pactl unload-module module-null-sink 2>/dev/null || true
  rm -f "$STATE"
  printf 'device\t%s\tremoved\n' "$NAME"
}
test_tone(){
  ensure >/dev/null || exit 1
  local wav; wav="$(mktemp --suffix=.wav)"
  ffmpeg -hide_banner -loglevel error -f lavfi -i "sine=frequency=440:duration=1" -ar 24000 -ac 1 "$wav" -y 2>/dev/null
  paplay --device="$NAME" "$wav" && printf 'tone\tplayed\t%s\n' "$NAME"
  rm -f "$wav"
}
case "$ACTION" in
  ensure) ensure ;;
  status) status ;;
  remove) remove ;;
  test) test_tone ;;
  *) printf 'usage: snotra-voice-device.sh ensure|status|remove|test\n' >&2; exit 2 ;;
esac
