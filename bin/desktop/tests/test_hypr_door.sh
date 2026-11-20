#!/usr/bin/env bash
# test_hypr_door.sh — the one Hyprland door (plan 341.1–341.3), proved in BOTH dialects with no compositor.
#
# Every case runs twice: against recorded `hyprctl -j` fixtures of a Lua Hyprland (0.56, an Omarchy config)
# and of a classic one. The stand-in hyprctl (fixtures/hypr/fake-hyprctl) refuses what the real dialect
# refuses, in its real words, so a verb that sends the wrong dialect FAILS here instead of landing nowhere
# on a desk — which is exactly how the helm's first two window-tells were lost on 2026-11-20.
#
# What is checked, and why each one matters:
#   dialect   the probe reads the answer, not only the exit code (classic says "unknown request" with exit 0)
#   windows   every window is listed, and the agent inside a terminal is named (walked from a fake /proc)
#   find      one address, or a refusal that names the candidates — never a silent first pick
#   focus     the right dispatcher for the dialect, and `back` returns to what had focus
#   type      types NOTHING while the desk is in a call, NOTHING when focus did not land, and gives focus back
#   workspace / move / set / notify    the right words for the dialect, and a refused act is a failure (exit 1)
#   config    Hyprland's errors and a broken ymir-*.lua are named by file and line; reload reports, never `|| true`
#   off-Hyprland  every verb but `dialect` refuses by name (exit 3)
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FX="$REPO/bin/desktop/tests/fixtures/hypr"
H="$REPO/bin/desktop/hypr.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# the desk door and the typist are stand-ins too: nothing here may type on a real desk
cat >"$T/in-call-free" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$T/in-call-held" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = holder ] && echo "Example Call"
exit 0
EOF
cat >"$T/wtype" <<'EOF'
#!/usr/bin/env bash
(IFS='|'; printf '%s\n' "$*") >>"$WTYPE_LOG"
EOF
chmod +x "$T/in-call-free" "$T/in-call-held" "$T/wtype"

for D in lua classic; do
  S="$T/$D"; mkdir -p "$S"
  export HYPR_FAKE_DIALECT="$D" HYPR_FAKE_DIR="$FX" HYPR_FAKE_STATE="$S/fake"
  export YMIR_HYPRCTL="$FX/fake-hyprctl" YMIR_HYPR_PROC="$FX/proc" YMIR_HYPR_STATE="$S/back"
  export YMIR_WTYPE="$T/wtype" WTYPE_LOG="$S/wtype.log" YMIR_IN_CALL="$T/in-call-free" YMIR_HYPR_SETTLE=0.2
  export YMIR_DISPLAYS_CONF="$S/none.conf"
  unset HYPR_FAKE_NOFOCUS HYPR_FAKE_CONFIGERRORS YMIR_HYPR_FIRST
  reset() { rm -rf "$S/fake" "$S/back" "$WTYPE_LOG"; }
  log() { cat "$S/fake/log" 2>/dev/null; }
  reset

  # dialect
  out="$(bash "$H" dialect)"
  check "$D: dialect probed as $D" '[[ "$out" == *"\"$D\""* ]]'
  [ "$D" = lua ] && check "$D: version read" '[[ "$out" == *"0.56.2"* ]]'

  # windows
  out="$(bash "$H" windows)"
  check "$D: windows lists all four" '[[ "$out" == "hypr-windows[4]"* ]]'
  check "$D: the agent inside the first terminal is named" 'printf "%s\n" "$out" | grep -q "\"0xa1\",\"foot\",1,0,4242,\"claude\""'
  check "$D: windows --json is JSON with an agent field" 'bash "$H" windows --json | python3 -c "import json,sys; d=json.load(sys.stdin); assert d[0][\"agent\"]==\"claude\""'

  # find
  check "$D: find by an exact class" '[ "$(bash "$H" find firefox)" = 0xb1 ]'
  err="$(bash "$H" find foot 2>&1 >/dev/null)"; rc=$?
  check "$D: two matches refuse (exit 4) and name both candidates" '[ $rc = 4 ] && [[ "$err" == *0xa1* ]] && [[ "$err" == *0xa2* ]]'
  check "$D: --first takes the first" '[ "$(bash "$H" find foot --first)" = 0xa1 ]'
  check "$D: find by pid" '[ "$(bash "$H" find 5100)" = 0xb1 ]'
  check "$D: find by title" '[ "$(bash "$H" find "notes" --title)" = 0xa2 ]'
  check "$D: find by address" '[ "$(bash "$H" find 0xc1)" = 0xc1 ]'
  bash "$H" find nothing-here >/dev/null 2>&1; rc=$?
  check "$D: no match is exit 4" '[ $rc = 4 ]'

  # focus / back
  reset
  bash "$H" focus firefox >/dev/null; rc=$?
  check "$D: focus lands (exit 0)" '[ $rc = 0 ]'
  if [ "$D" = lua ]; then
    check "$D: focus spoke Lua" 'log | grep -qF "dispatch|hl.dsp.focus({ window = \"address:0xb1\" })"'
  else
    check "$D: focus spoke classic" 'log | grep -qx "dispatch|focuswindow|address:0xb1"'
  fi
  check "$D: focus remembered what had focus" '[ "$(cat "$S/back")" = 0xa1 ]'
  bash "$H" back >/dev/null; rc=$?
  check "$D: back returns focus to 0xa1" '[ $rc = 0 ] && [ "$(cat "$S/fake/active")" = 0xa1 ]'

  # type — the guarded verb
  reset
  YMIR_IN_CALL="$T/in-call-held" bash "$H" type firefox "hello" >/dev/null 2>&1; rc=$?
  check "$D: type refuses while the desk is in a call (exit 3)" '[ $rc = 3 ]'
  check "$D: …and typed nothing, and focused nothing" '[ ! -s "$WTYPE_LOG" ] && ! log | grep -q dispatch'
  reset
  HYPR_FAKE_NOFOCUS=1 bash "$H" type firefox "hello" >/dev/null 2>&1; rc=$?
  check "$D: type refuses when focus does not land (exit 4)" '[ $rc = 4 ]'
  check "$D: …and typed nothing" '[ ! -s "$WTYPE_LOG" ]'
  reset
  out="$(bash "$H" type firefox "hello world")"; rc=$?
  check "$D: type lands (exit 0)" '[ $rc = 0 ]'
  check "$D: the line was typed, then Enter" '[ "$(sed -n 1p "$WTYPE_LOG")" = "--|hello world" ] && [ "$(sed -n 2p "$WTYPE_LOG")" = "-k|Return" ]'
  check "$D: focus was given back to 0xa1" '[ "$(cat "$S/fake/active")" = 0xa1 ] && [[ "$out" == *"\"0xa1\""* ]]'
  reset
  bash "$H" type firefox "no enter" --no-enter --stay >/dev/null
  check "$D: --no-enter --stay types without Enter and keeps focus" '[ "$(wc -l <"$WTYPE_LOG")" = 1 ] && [ "$(cat "$S/fake/active")" = 0xb1 ]'
  reset
  bash "$H" type foot "x" >/dev/null 2>&1; rc=$?
  check "$D: type into an ambiguous window refuses and types nothing" '[ $rc = 4 ] && [ ! -s "$WTYPE_LOG" ]'

  # workspace / move
  reset
  bash "$H" workspace 3 >/dev/null
  if [ "$D" = lua ]; then check "$D: workspace spoke Lua" 'log | grep -qF "dispatch|hl.dsp.focus({ workspace = \"3\" })"'
  else check "$D: workspace spoke classic" 'log | grep -qx "dispatch|workspace|3"'; fi
  reset
  bash "$H" move firefox --workspace 6 >/dev/null; rc=$?
  if [ "$D" = lua ]; then check "$D: move --workspace spoke Lua, silently" '[ $rc = 0 ] && log | grep -qF "workspace = \"6\", follow = false"'
  else check "$D: move --workspace spoke classic, silently" '[ $rc = 0 ] && log | grep -qx "dispatch|movetoworkspacesilent|6,address:0xb1"'; fi
  reset
  bash "$H" move 0xa1 --monitor reading >/dev/null; rc=$?
  if [ "$D" = lua ]; then check "$D: move --monitor reading -> the largest (HDMI-A-1), in Lua" '[ $rc = 0 ] && log | grep -qF "monitor = \"HDMI-A-1\""'
  else check "$D: move --monitor reading -> the largest (HDMI-A-1), classic" '[ $rc = 0 ] && log | grep -qx "dispatch|movewindow|mon:HDMI-A-1"'; fi

  # set
  reset
  bash "$H" set general:gaps_in 5 >/dev/null; rc=$?
  if [ "$D" = lua ]; then check "$D: set is an eval of hl.config" '[ $rc = 0 ] && log | grep -qxF "eval|hl.config({ general = { gaps_in = 5 } })"'
  else check "$D: set is a keyword" '[ $rc = 0 ] && log | grep -qx "keyword|general:gaps_in|5"'; fi
  reset
  bash "$H" set general:layout scrolling >/dev/null
  if [ "$D" = lua ]; then check "$D: a word value is a quoted Lua string" 'log | grep -qxF "eval|hl.config({ general = { layout = \"scrolling\" } })"'; fi
  if [ "$D" = lua ]; then
    bash "$H" set decoration:bad_key 1 >/dev/null 2>&1; rc=$?
    check "$D: an option Hyprland refuses is exit 1, not a green" '[ $rc = 1 ]'
  fi
  bash "$H" set 'a b' 1 >/dev/null 2>&1; rc=$?
  check "$D: a malformed option name is a usage error" '[ $rc = 2 ]'

  # notify
  reset
  bash "$H" notify "the rail is down" >/dev/null
  check "$D: notify reached Hyprland" 'log | grep -q "^notify|-1|5000|0|the rail is down$"'

  # config check / reload
  CF="$S/hypr"; mkdir -p "$CF"
  printf -- '-- generated\no.rebind("SUPER + Y", "Ymir", "ymir-app hlidskjalf")\n' >"$CF/ymir-launchers.lua"
  out="$(bash "$H" config check --dir "$CF")"; rc=$?
  check "$D: config check is clean on a clean config" '[ $rc = 0 ] && [[ "$out" == *clean* ]]'
  printf '%s\n' "$CF/ymir-desktops.lua:12: attempt to call a nil value" >"$S/errs"
  out="$(HYPR_FAKE_CONFIGERRORS="$S/errs" bash "$H" config check --dir "$CF" 2>&1)"; rc=$?
  check "$D: Hyprland's own error is named by file and line" '[ $rc = 1 ] && [[ "$out" == *"ymir-desktops.lua\",\"12\""* ]]'
  if [ "$D" = lua ]; then
    if command -v luac >/dev/null 2>&1; then
      printf -- '-- generated\no.rebind("SUPER + Y", "Ymir",\no.rebind("SUPER + M" "x")\n' >"$CF/ymir-launchers.lua"
      reset
      out="$(bash "$H" config reload --dir "$CF" 2>&1)"; rc=$?
      check "$D: config reload asked Hyprland to reload" 'log | grep -qx reload'
      check "$D: a broken ymir-launchers.lua is named by file and line after a reload (exit 1)" \
        '[ $rc = 1 ] && [[ "$out" == *"ymir-launchers.lua\",\"3\""* ]] && [[ "$out" == *"broken at $CF/ymir-launchers.lua:3"* ]]'
    else
      printf 'skip - luac is not on this machine: the syntax half of config check is a named skip\n'
    fi
  fi

  # the dialect never leaks: Lua never received a classic dispatcher, classic never received hl.*
  if [ "$D" = lua ]; then check "$D: no classic dispatcher string was ever sent" '! grep -h "^dispatch|" "$S"/fake/log 2>/dev/null | grep -qv "^dispatch|hl\."'
  else check "$D: no hl.* expression was ever sent" '! grep -h "^dispatch|hl\." "$S"/fake/log 2>/dev/null | grep -q .'; fi
done

# off Hyprland
export YMIR_HYPRCTL="$T/no-such-hyprctl"
for v in windows "find foot" "focus foot" "type foot x" "workspace 1" "config check" "set a:b 1"; do
  # shellcheck disable=SC2086
  bash "$H" $v >/dev/null 2>&1; rc=$?
  check "off Hyprland: '$v' refuses by name (exit 3)" '[ $rc = 3 ]'
done
out="$(bash "$H" dialect)"
check "off Hyprland: dialect says none (exit 0)" '[[ "$out" == *"\"none\""* ]]'

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
