#!/usr/bin/env bash
# in-call.sh — the one door that says whether the operator is in a call (plan 271).
#
# A call (Discord, Meet, Zoom, MiroTalk, anything) shows up as a capture stream on the
# sound server. While one is live on a dev seat, nothing the helm or a worker starts may
# touch the desk's GPU or audio: no voice engine, no speech model, no rail model load, no
# desktop app launch. Every such door asks this one.
#
# Usage:
#   in-call.sh check [--now] [--what <words>]   exit 0 free · 3 held (names the holder)
#   in-call.sh holder                           the first holder's name, or nothing
#   in-call.sh source                           the source name the call is capturing from
#   in-call.sh bluetooth                        exit 0 when that source is a Bluetooth headset
#   in-call.sh inputs                           how many real (non-monitor) microphones exist right now
#   in-call.sh role                             the seat role the guard acts on
#
# THE LAW (plan 259 B2e): the sound server is shared. Nothing this guard guards, and nothing that
# asks it, may restart pipewire, wireplumber or any system-wide audio unit as a remedy — that drops
# every other client in the same second, which is how a small fault becomes a meeting lost. The
# remedy for a lost stream is the APPLICATION re-opening it.
#
# Env (all optional):
#   YMIR_DESK_NOW=1        the operator's explicit "now" (same as --now)
#   YMIR_DESK_ROLE         override the seat role (default: bin/skuld/role.sh resolve)
#   YMIR_DESK_GUARD_ROLES  roles the guard acts on        (default: dev)
#   YMIR_DESK_IGNORE       extended regex of capture clients that are not calls
#                          (default: this house's own voice engine and Rödd's window)
#
# A server or a hand seat has no desk: the guard reports free there (a clean skip, said).
# Exit: 0 free · 3 held · 2 usage.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
IGNORE="${YMIR_DESK_IGNORE:-^(speech-to-speech|ymir-voice|@zerwiz/rodd|rodd)$}"
GUARD_ROLES="${YMIR_DESK_GUARD_ROLES:-dev}"

seat_role() {
  if [ -n "${YMIR_DESK_ROLE:-}" ]; then printf '%s' "$YMIR_DESK_ROLE"; return; fi
  bash "$ROOT/bin/skuld/role.sh" resolve 2>/dev/null | head -1 || true
}

# TSV rows: holder-name <TAB> source-name — one per live capture stream
streams() {
  command -v pactl >/dev/null 2>&1 || return 0
  { pactl list source-outputs 2>/dev/null; echo '=====SOURCES'; pactl list short sources 2>/dev/null; } | python3 -c '
import re, sys
text = sys.stdin.read()
outs, _, srcs = text.partition("=====SOURCES")
names = {}
for line in srcs.splitlines():
    f = line.split("\t")
    if len(f) >= 2: names[f[0]] = f[1]
for blk in re.split(r"\n(?=Source Output #)", outs):
    if not blk.startswith("Source Output #"): continue
    def prop(k):
        m = re.search(r"^\s*" + re.escape(k) + r" = \"(.*)\"", blk, re.M)
        return m.group(1) if m else ""
    src = re.search(r"^\s*Source: (\S+)", blk, re.M)
    name = prop("application.name") or prop("application.process.binary") or prop("node.name") or "an unnamed client"
    sname = names.get(src.group(1), "") if src else ""
    # a monitor tap (a level meter, a recorder of the speakers) is not a call
    if sname.endswith(".monitor"): continue
    print(name + "\t" + sname)
'
}

holders() {
  streams | while IFS=$'\t' read -r name src; do
    printf '%s\n' "$name" | grep -qiE "$IGNORE" && continue
    printf '%s\t%s\n' "$name" "$src"
  done
}

cmd="${1-}"; shift || true
case "$cmd" in
  role) seat_role; echo; exit 0 ;;
  inputs) command -v pactl >/dev/null 2>&1 || exit 0
          pactl list short sources 2>/dev/null | awk '$2 !~ /\.monitor$/' | wc -l; exit 0 ;;
  holder) holders | head -1 | cut -f1; exit 0 ;;
  source) holders | head -1 | cut -f2; exit 0 ;;
  bluetooth)
    s="$(holders | head -1 | cut -f2)"
    case "$s" in *bluez*) exit 0 ;; *) exit 1 ;; esac ;;
  check)
    now="${YMIR_DESK_NOW:-0}"; what="this"
    while [ $# -gt 0 ]; do case "$1" in --now) now=1 ;; --what) shift; what="${1:-this}" ;; esac; shift; done
    role="$(seat_role)"
    case " $GUARD_ROLES " in *" $role "*) ;; *) exit 0 ;; esac   # no desk on this role
    h="$(holders | head -1 | cut -f1)"
    [ -n "$h" ] || exit 0
    if [ "$now" = 1 ]; then
      printf 'in-call: %s holds the microphone — proceeding with %s on the operator'"'"'s explicit --now\n' "$h" "$what" >&2
      exit 0
    fi
    printf 'refused: %s holds the microphone — the operator is in a call, so %s will not start\n' "$h" "$what" >&2
    printf 'hint: wait for the call to end, or the operator says "now" (--now / YMIR_DESK_NOW=1) — and never restart pipewire or wireplumber to get around it\n' >&2
    exit 3 ;;
  *) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
