#!/usr/bin/env bash
# window-tell.sh — hand one line to an agent that runs in a plain terminal WINDOW, not a herdr pane.
#
# eindri-send.sh reaches an agent seated in herdr. An agent the operator started by hand in a terminal
# (foot, kitty, alacritty, ghostty …) has no inbox, and the kernel's tty injection (TIOCSTI) is off by
# design. So this door does what a person would do: it finds the window that owns the agent's process,
# focuses it, types the line through the compositor, presses Enter, and gives focus back.
#
# A long message never goes through the keyboard: write it to a letter file and send the line
# "read <letter>". With --letter, this door writes the letter for you and types only the pointer.
#
# Usage:
#   window-tell.sh --list                                  # every terminal agent it can reach
#   window-tell.sh [--from <who>] <target> "<line>"        # type one line
#   window-tell.sh [--from <who>] --letter <file> <target> # hand a letter (stdin -> file), type the pointer
#   window-tell.sh --dry-run …                             # say what it would do, type nothing
#
# <target> is an agent pid, a terminal pid, a window address (0x…), or a word matched against the
# window title and the agent's working directory.
#
# Requires: Hyprland (hyprctl) and wtype, on Wayland. Elsewhere it refuses by name — a clean skip, never a guess.
# Safety: it types ONLY if the focused window is the target after focusing; otherwise it types nothing.
set -euo pipefail

FROM="script window-tell"
DRY=0
LETTER=""
AGENTS_RE="${WINDOW_TELL_AGENTS:-claude|codex|opencode|pi|omp|gemini|aider}"
TERMS_RE="${WINDOW_TELL_TERMS:-foot|kitty|alacritty|ghostty|wezterm|konsole|gnome-terminal|xterm|waveterm}"

die() { printf 'window-tell: %s\n' "$*" >&2; exit 2; }

need() {
  [ -n "${WAYLAND_DISPLAY:-}" ] || die "no Wayland session — skip (this door needs a compositor)"
  command -v hyprctl >/dev/null || die "hyprctl not found — skip (only Hyprland is supported today)"
  command -v wtype >/dev/null || die "wtype not found — install it (pacman -S wtype)"
  command -v python3 >/dev/null || die "python3 not found"
}

# The window manager's dialect (Lua vs classic) is display-lib's to know, never this file's.
# shellcheck source=../desktop/display-lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../desktop" && pwd)/display-lib.sh"
focus() { window_focus "$1" || true; }
active_addr() { hyprctl activewindow -j | python3 -c 'import json,sys;print(json.load(sys.stdin).get("address",""))'; }

# One TOON-ish row per agent process whose ancestor is a terminal window: agent_pid term_pid address title cwd
list_rows() {
  python3 - "$AGENTS_RE" "$TERMS_RE" <<'PY'
import json, os, re, subprocess, sys
agents, terms = re.compile(sys.argv[1]), re.compile(sys.argv[2])
wins = {c["pid"]: c for c in json.loads(subprocess.check_output(["hyprctl", "clients", "-j"]))}
def comm(p):
    try: return open(f"/proc/{p}/comm").read().strip()
    except OSError: return ""
def ppid(p):
    try: return int(open(f"/proc/{p}/stat").read().rsplit(")", 1)[1].split()[1])
    except (OSError, IndexError, ValueError): return 0
seen = set()
for d in os.listdir("/proc"):
    if not d.isdigit(): continue
    p = int(d); c = comm(p)
    if not agents.fullmatch(c): continue
    q = ppid(p)
    if agents.fullmatch(comm(q)): continue          # a child of another agent process
    while q > 1 and q not in wins: q = ppid(q)
    if q <= 1 or not terms.search(wins[q]["class"]) or p in seen: continue
    seen.add(p)
    try: cwd = os.readlink(f"/proc/{p}/cwd")
    except OSError: cwd = "?"
    w = wins[q]
    print("\t".join([str(p), c, str(q), w["address"], w["workspace"]["name"], w["title"][:60], cwd]))
PY
}

resolve() {
  local t="$1" rows hit
  rows="$(list_rows)"
  [ -n "$rows" ] || die "no agent stands in any terminal window"
  hit="$(printf '%s\n' "$rows" | awk -F'\t' -v t="$t" '$1==t || $3==t || $4==t')"
  [ -n "$hit" ] || hit="$(printf '%s\n' "$rows" | awk -F'\t' -v t="$t" 'index(tolower($6" "$7), tolower(t))')"
  [ -n "$hit" ] || die "no terminal agent matches '$t' — see --list"
  [ "$(printf '%s\n' "$hit" | wc -l)" -eq 1 ] || { printf '%s\n' "$hit" >&2; die "'$t' matches more than one window — name a pid"; }
  printf '%s\n' "$hit"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --list) need; printf 'agents{pid,agent,term_pid,address,workspace,title,cwd}:\n'
            list_rows | awk -F'\t' '{printf "  %s,%s,%s,%s,%s,\"%s\",%s\n",$1,$2,$3,$4,$5,$6,$7}'; exit 0 ;;
    --from) FROM="$2"; shift 2 ;;
    --letter) LETTER="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) break ;;
  esac
done
[ $# -ge 1 ] || die "usage: window-tell.sh [--from <who>] [--letter <file>] <target> \"<line>\""
need
target="$1"; shift
row="$(resolve "$target")"
IFS=$'\t' read -r apid agent tpid addr ws title cwd <<<"$row"

if [ -n "$LETTER" ]; then
  mkdir -p "$(dirname "$LETTER")"
  if [ ! -t 0 ]; then cat >"$LETTER"; fi
  [ -s "$LETTER" ] || die "the letter $LETTER is empty"
  line="Please read $LETTER and answer by appending to it.${1:+ $1}"
else
  [ $# -ge 1 ] || die "no line to type"
  line="$1"
fi
case "$line" in *$'\n'*) die "one line only — put a long message in a letter (--letter)";; esac
text="[from $FROM] $line"

printf 'window-tell: %s (pid %s) in %s window %s on workspace %s — "%s"\n' "$agent" "$apid" "$(hyprctl clients -j | python3 -c "import json,sys;print(next((c['class'] for c in json.load(sys.stdin) if c['address']=='$addr'),'?'))")" "$addr" "$ws" "$title"
if [ "$DRY" = 1 ]; then printf 'window-tell: dry run — would type: %s\n' "$text"; exit 0; fi

back="$(active_addr)"
focus "$addr"; sleep 0.6
if [ "$(active_addr)" != "$addr" ]; then
  focus "$back"; die "focus did not land on $addr — typed nothing"
fi
wtype "$text"; sleep 0.3; wtype -k Return
sleep 0.3; [ -n "$back" ] && [ "$back" != "$addr" ] && focus "$back"
printf 'window-tell: handed — a tell is HANDED, not done, until the agent answers\n'
