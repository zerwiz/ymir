#!/usr/bin/env bash
# ymir-edit-display.test.sh — the editor door places windows the way it says it does.
#
# A fake `hyprctl` (YMIR_HYPRCTL) stands in for the window manager and a fake editor
# stands in for MarkText, so the DECISIONS are asserted without a display: which
# monitor a role resolves to, which dispatcher dialect is spoken, that a file is
# never opened twice, and that a machine with no window manager still opens the file.
#
# The bug this test exists for: the old door moved windows with the classic
# `movetoworkspacesilent <n>,class:x` string. On Hyprland 0.56 (an Omarchy Lua config)
# that fails, the fallback was a window RULE (which applies to the next window, not
# this one), and so the tool reported success while the window never moved.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EDIT="$ROOT/bin/engine/ymir-edit.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export XDG_CONFIG_HOME="$TMP/config"; mkdir -p "$XDG_CONFIG_HOME/ymir" "$TMP/bin"
CLIENTS="$TMP/clients.json"; DISPATCH="$TMP/dispatch.log"
printf '[]' >"$CLIENTS"; : >"$DISPATCH"

cat >"$TMP/bin/hyprctl" <<'FAKE'
#!/usr/bin/env bash
case "${1:-}" in
  eval)      [ "${FAKE_LUA:-1}" = 1 ] && { echo ok; exit 0; }; exit 1 ;;
  monitors)  printf '%s' '[
    {"name":"eDP-1","width":1920,"height":1080,"focused":false},
    {"name":"HDMI-A-1","width":2560,"height":1080,"focused":false},
    {"name":"DP-3","width":1920,"height":1080,"focused":true}]' ;;
  clients)   cat "${FAKE_CLIENTS:?}" ;;
  workspaces) printf '%s' '[{"id":1,"windows":2},{"id":8,"windows":0}]' ;;
  dispatch)  printf '%s\n' "$2" >>"${FAKE_DISPATCH:?}"; echo ok ;;
  keyword)   echo ok ;;
  version)   echo '{"version":"0.56.2"}' ;;
  *)         exit 1 ;;
esac
FAKE
chmod +x "$TMP/bin/hyprctl"

cat >"$TMP/bin/marktext" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$1" >>"${FAKE_LAUNCHES:?}"
python3 - "$FAKE_CLIENTS" "$1" <<'PY'
import json,sys,os
p,f=sys.argv[1],sys.argv[2]
try: ws=json.load(open(p))
except Exception: ws=[]
ws.append({"address":"0xabc123","class":"marktext","title":os.path.basename(f)+" - MarkText",
           "monitor":0,"workspace":{"id":1},"at":[0,0],"size":[800,600]})
json.dump(ws,open(p,"w"))
PY
FAKE
chmod +x "$TMP/bin/marktext"

export FAKE_CLIENTS="$CLIENTS" FAKE_DISPATCH="$DISPATCH" FAKE_LAUNCHES="$TMP/launches"
export YMIR_HYPRCTL="$TMP/bin/hyprctl" YMIR_EDITOR="$TMP/bin/marktext"
export PATH="$TMP/bin:$PATH"
DOC="$TMP/plan.md"; printf '# plan\n' >"$DOC"

# 1 — a role resolves to a DISPLAY: reading = the largest, and the dialect is probed
out="$(bash "$EDIT" --role reading --dry-run "$DOC" 2>&1)"
printf '%s' "$out" | grep -q '"reading","HDMI-A-1","lua"' && ok "role reading -> the largest display (HDMI-A-1), dialect lua" \
  || bad "dry-run: $out"

# 2 — opening places the window with the LUA dispatcher on that display
out="$(bash "$EDIT" --role reading "$DOC" 2>&1)"; rc=$?
grep -q 'hl\.dsp\.window\.move' "$DISPATCH" && grep -q 'HDMI-A-1' "$DISPATCH" \
  && ok "placed with the Lua dispatcher on HDMI-A-1" || bad "dispatch: $(cat "$DISPATCH")"
printf '%s' "$out" | grep -q '"yes"' && ok "the report says placed" || bad "report: $out"
[ "$rc" = 0 ] && ok "exit 0 when placed" || bad "exit $rc"

# 3 — a second call REUSES the window: the editor is not launched twice
before="$(wc -l <"$TMP/launches")"
out="$(bash "$EDIT" --role reading "$DOC" 2>&1)"
after="$(wc -l <"$TMP/launches")"
[ "$before" = "$after" ] && ok "a second call does not open a second window" || bad "launches $before -> $after"
printf '%s' "$out" | grep -q '"1","yes"' && ok "the report says reused" || bad "reuse report: $out"

# 4 — --new forces another window
bash "$EDIT" --role reading --new "$DOC" >/dev/null 2>&1
[ "$(wc -l <"$TMP/launches")" -gt "$after" ] && ok "--new opens another window" || bad "--new did not relaunch"

# 5 — the classic dialect falls back to the classic dispatcher
: >"$DISPATCH"; printf '[]' >"$CLIENTS"
FAKE_LUA=0 bash "$EDIT" --role code "$DOC" >/dev/null 2>&1
grep -q 'movewindow' "$DISPATCH" && ok "classic dialect falls back to movewindow" || bad "classic: $(cat "$DISPATCH")"

# 6 — the operator's recorded choice wins over the default
printf 'reading = eDP-1\n' >"$XDG_CONFIG_HOME/ymir/displays.conf"
out="$(bash "$EDIT" --role reading --dry-run "$DOC" 2>&1)"
printf '%s' "$out" | grep -q '"eDP-1"' && ok "a recorded displays.conf entry wins" || bad "conf override: $out"
rm -f "$XDG_CONFIG_HOME/ymir/displays.conf"

# 7 — a monitor named directly passes through
out="$(bash "$EDIT" --role DP-3 --dry-run "$DOC" 2>&1)"
printf '%s' "$out" | grep -q '"DP-3"' && ok "a monitor named directly passes through" || bad "named monitor: $out"

# 8 — a numbered desktop still works, and it too speaks the right dialect
printf '[]' >"$CLIENTS"; : >"$DISPATCH"
bash "$EDIT" --desktop 8 "$DOC" >/dev/null 2>&1
grep -q 'workspace = 8' "$DISPATCH" && ok "a numbered desktop is placed with the Lua dispatcher" \
  || bad "desktop move: $(cat "$DISPATCH")"

# 9 — no window manager: the file still opens and nothing is claimed
printf '[]' >"$CLIENTS"
before="$(wc -l <"$TMP/launches")"
out="$(YMIR_HYPRCTL=/nonexistent/hyprctl bash "$EDIT" --role reading "$DOC" 2>&1)"
[ "$(wc -l <"$TMP/launches")" -gt "$before" ] && ok "no window manager: the file still opens" || bad "no-wm: the editor did not run"
printf '%s' "$out" | grep -q '"no"' && ok "no window manager: placement is not claimed" || bad "no-wm report: $out"

# 10 — no path prints the usage, exits 0 (the door's own convention), and opens nothing
out="$(bash "$EDIT" 2>&1)"; rc=$?
printf '%s' "$out" | grep -qi 'usage' && [ "$rc" = 0 ] && ok "no path prints usage, opens nothing (exit 0)" \
  || bad "no-path: rc=$rc out=$out"

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
