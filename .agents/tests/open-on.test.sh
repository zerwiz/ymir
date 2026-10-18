#!/usr/bin/env bash
# open-on.test.sh — the display-aware opener, proved without a display.
#
# A fake `hyprctl` stands in for the window manager (YMIR_HYPRCTL), so the test
# asserts the DECISIONS: which monitor a role resolves to, which dispatcher
# dialect is used, that a file is never opened twice, and that a box with no
# window manager still opens the file and says placement was skipped.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPEN="$ROOT/bin/seat/sessrumnir/open-on.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export XDG_CONFIG_HOME="$TMP/config"; mkdir -p "$XDG_CONFIG_HOME/ymir" "$TMP/bin"
CLIENTS="$TMP/clients.json"; DISPATCH="$TMP/dispatch.log"
printf '[]' >"$CLIENTS"; : >"$DISPATCH"

# ── the fake window manager ──────────────────────────────────────────────────
cat >"$TMP/bin/hyprctl" <<'FAKE'
#!/usr/bin/env bash
case "${1:-}" in
  eval)      [ "${FAKE_LUA:-1}" = 1 ] && { echo ok; exit 0; }; exit 1 ;;
  monitors)  printf '%s' '[
    {"name":"eDP-1","width":1920,"height":1080,"focused":true},
    {"name":"HDMI-A-1","width":2560,"height":1080,"focused":false},
    {"name":"DP-3","width":1920,"height":1080,"focused":false}]' ;;
  clients)   cat "${FAKE_CLIENTS:?}" ;;
  dispatch)  printf '%s\n' "$2" >>"${FAKE_DISPATCH:?}"; echo ok ;;
  version)   echo '{"version":"0.56.2"}' ;;
  *)         exit 1 ;;
esac
FAKE
chmod +x "$TMP/bin/hyprctl"

# ── a fake editor that "opens a window" the moment it starts ─────────────────
cat >"$TMP/bin/marktext" <<'FAKE'
#!/usr/bin/env bash
f="$1"
printf '%s\n' "$f" >>"${FAKE_LAUNCHES:?}"
python3 - "$FAKE_CLIENTS" "$f" <<'PY'
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

# 1 — the role resolves to the LARGEST monitor, and the dialect is lua
out="$(bash "$OPEN" "$DOC" --role reading --dry-run 2>&1)"
printf '%s' "$out" | grep -q '"HDMI-A-1","lua"' && ok "role reading -> the largest monitor (HDMI-A-1), dialect lua" \
  || bad "reading role: $out"

# 2 — opening places it with the LUA dispatcher on that monitor
out="$(bash "$OPEN" "$DOC" --role reading 2>&1)"; rc=$?
grep -q 'hl\.dsp\.window\.move' "$DISPATCH" && grep -q 'HDMI-A-1' "$DISPATCH" \
  && ok "placed with the Lua dispatcher on HDMI-A-1" || bad "dispatch: $(cat "$DISPATCH")"
printf '%s' "$out" | grep -q '"yes"' && ok "the report says placed" || bad "report: $out"
[ "$rc" = 0 ] && ok "exit 0 when placed" || bad "exit $rc"

# 3 — a second call REUSES the window: the editor is launched once, not twice
before="$(wc -l <"$TMP/launches")"
out="$(bash "$OPEN" "$DOC" --role reading 2>&1)"
after="$(wc -l <"$TMP/launches")"
[ "$before" = "$after" ] && ok "a second call does not open a second window" || bad "launches went $before -> $after"
printf '%s' "$out" | grep -q ',1,"reading"' && ok "the report says reused" || bad "reuse report: $out"

# 4 — --new forces another window
bash "$OPEN" "$DOC" --role reading --new >/dev/null 2>&1
[ "$(wc -l <"$TMP/launches")" -gt "$after" ] && ok "--new opens another window" || bad "--new did not relaunch"

# 5 — the classic dialect is used when the instance is not Lua
: >"$DISPATCH"; printf '[]' >"$CLIENTS"
FAKE_LUA=0 bash "$OPEN" "$DOC" --role code >/dev/null 2>&1
grep -q 'movewindow' "$DISPATCH" && ok "classic dialect falls back to movewindow" \
  || bad "classic dispatch: $(cat "$DISPATCH")"

# 6 — the operator's recorded choice wins over the default
printf 'reading = eDP-1\n' >"$XDG_CONFIG_HOME/ymir/displays.conf"
out="$(bash "$OPEN" "$DOC" --role reading --dry-run 2>&1)"
printf '%s' "$out" | grep -q '"eDP-1"' && ok "a recorded displays.conf entry wins" || bad "conf override: $out"
rm -f "$XDG_CONFIG_HOME/ymir/displays.conf"

# 7 — an explicit monitor name passes through
out="$(bash "$OPEN" "$DOC" --role DP-3 --dry-run 2>&1)"
printf '%s' "$out" | grep -q '"DP-3"' && ok "a monitor named directly passes through" || bad "named monitor: $out"

# 8 — no window manager: the file still opens, placement is skipped, exit 3
printf '[]' >"$CLIENTS"
out="$(YMIR_HYPRCTL=/nonexistent/hyprctl bash "$OPEN" "$DOC" 2>&1)"; rc=$?
[ "$rc" = 3 ] && ok "no window manager -> exit 3 (opened, unplaced)" || bad "no-wm exit $rc: $out"
printf '%s' "$out" | grep -qi 'placement skipped' && ok "no window manager -> the skip is said plainly" || bad "no-wm note: $out"

# 9 — a missing file is refused, not opened
bash "$OPEN" "$TMP/nope.md" >/dev/null 2>&1; [ "$?" = 1 ] && ok "a missing file exits 1" || bad "missing file exit"

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
