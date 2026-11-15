#!/usr/bin/env bash
# echo-cancel.sh — Ymir's own microphone without the speakers in it (plan 275 S22).
#
#   bin/voice/echo-cancel.sh start     raise it (idempotent)
#   bin/voice/echo-cancel.sh stop      lower it (only its own process; nothing else is touched)
#   bin/voice/echo-cancel.sh status    up · the source name · the process
#
# WHY (measured on the dev machine, 2026-11-12). Rödd shares the built-in microphone with the built-in speakers. A video in
# the browser and the Discord call on those speakers were heard as speech: 743 turns started in one evening and every
# answer was cancelled ("speech during response"). The browser's own echo canceller removes only Rödd's own voice, not
# another program's sound.
#
# HOW, inside the house's law (Ymir never changes the user's sound system): this runs PipeWire's own echo-cancel
# module with the WebRTC canceller in a SEPARATE PipeWire client process that Ymir owns. It reads the default
# microphone, uses the default speakers' monitor as the echo reference (monitor mode: nobody's sound is rerouted),
# and offers one new source, "Ymir · microphone without the speakers". It sets no default device, loads nothing into
# the session's own server, restarts nothing, and when it stops, only its own source disappears. Rödd records from
# that source when it exists, and from the plain microphone when it does not.
#
# Settings (RULES/07): YMIR_EC_SOURCE (ymir-echo-cancel), YMIR_EC_UNIT (ymir-echo-cancel).
set -u
SRC="${YMIR_EC_SOURCE:-ymir-echo-cancel}"
UNIT="${YMIR_EC_UNIT:-ymir-echo-cancel}"
CONF_DIR="${XDG_RUNTIME_DIR:-/tmp}/ymir"
CONF="$CONF_DIR/echo-cancel.conf"

up() { pactl list short sources 2>/dev/null | awk '{print $2}' | grep -qx "$SRC"; }

write_conf() {
  mkdir -p "$CONF_DIR"
  cat > "$CONF" <<EOF
# written by bin/voice/echo-cancel.sh — Ymir's own PipeWire client; never the session's server
context.properties = { log.level = 2 }
context.spa-libs = {
  audio.convert.* = audioconvert/libspa-audioconvert
  support.*       = support/libspa-support
}
context.modules = [
  { name = libpipewire-module-rt        flags = [ ifexists nofail ] }
  { name = libpipewire-module-protocol-native }
  { name = libpipewire-module-client-node }
  { name = libpipewire-module-adapter }
  { name = libpipewire-module-echo-cancel
    args = {
      library.name  = aec/libspa-aec-webrtc
      monitor.mode  = true
      node.latency  = 1024/48000
      capture.props  = { node.name = "ymir-ec-capture"  node.passive = true }
      source.props   = { node.name = "$SRC" node.description = "Ymir · microphone without the speakers"
                         priority.session = 1 priority.driver = 1 }
      playback.props = { node.name = "ymir-ec-playback" node.passive = true }
    }
  }
]
EOF
}

case "${1:-status}" in
  start)
    if up; then printf 'echo-cancel\tup\t%s\n' "$SRC"; exit 0; fi
    write_conf
    systemd-run --user --quiet --collect --unit="$UNIT" --description="Ymir · microphone without the speakers" \
      -p Nice=5 pipewire -c "$CONF" >/dev/null 2>&1 || { printf 'echo-cancel\tFAIL\tthe client did not start\n' >&2; exit 1; }
    for _ in $(seq 1 20); do up && break; sleep 0.25; done
    if up; then printf 'echo-cancel\tup\t%s\n' "$SRC"; else printf 'echo-cancel\tFAIL\tno source appeared — journalctl --user -u %s\n' "$UNIT" >&2; exit 1; fi ;;
  stop)
    systemctl --user stop "$UNIT" >/dev/null 2>&1; printf 'echo-cancel\tdown\n' ;;
  status)
    if up; then printf 'echo-cancel\tup\t%s\t%s\n' "$SRC" "$(systemctl --user show -p MainPID --value "$UNIT" 2>/dev/null)"
    else printf 'echo-cancel\tdown\n'; exit 1; fi ;;
  *) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
