#!/usr/bin/env bash
# test_eir_true_mends.sh — the three Eir rows that lied or could not mend themselves (2026-11-20).
#
#   1. GATES      the pre-push hook that was installed ran NOTHING (a copy in `<git-dir>/hooks`
#                 resolved its root as `.git`, found no `bin/gates/guards.sh`, and skipped every
#                 ward), while the row was red for a string the shipped hook had dropped. Proven
#                 here by PUSHING in a throwaway repository and looking for the wards' own words.
#   2. RUNTIMEPIN `ymir-rodd.service` runs from the apps home (`bin/apps/app-path.sh`); it was
#                 reported UNREGISTERED and `units.sh write` would have retargeted it into a pin
#                 that no longer carries `apps/rodd`. Proven with a fake unit under a temp apps home.
#   3. AGENTROAD  the mend wrote the relay's unit and never enabled it, so the row it printed a
#                 command for could not go green. Proven by calling the mend with stub doors.
#
# Usage: test_eir_true_mends.sh     Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
EIR="$ROOT/bin/agents/eir-doctor.sh"
UNITS="$ROOT/bin/engine/units.py"
FIXES="$ROOT/bin/gates/guards/fixes-guard.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }
g()   { git -C "$1" -c user.email=t@example.org -c user.name=t -c commit.gpgsign=false "${@:2}"; }
# extract_fn <file> <name> — print one shell function, so a mend can be judged in isolation
extract_fn() { awk -v n="$2" 'index($0, n "()") == 1 { p=1 } p { print } p && /^}/ { exit }' "$1"; }

# ── 1. GATES: the seated hook must RUN the wards, and the install must seat it for the pushing tree ──
printf 'gates:\n'
R="$T/repo"
mkdir -p "$R/.pi" "$R/RULES" "$R/.githooks" "$R/bin/gates/guards"
cp "$ROOT/.githooks/pre-push" "$ROOT/.githooks/pre-commit" "$ROOT/.githooks/commit-msg" "$R/.githooks/"
cp "$FIXES" "$R/bin/gates/guards/fixes-guard.sh"
cp "$ROOT/bin/gates/guards/secret-guard.sh" "$R/bin/gates/guards/secret-guard.sh"
# a stubbed chain: the hook's own words are what prove it RAN
printf '#!/usr/bin/env bash\necho "WARD-RAN: the tree wards were called"\nexit 0\n' >"$R/bin/gates/guards.sh"; chmod +x "$R/bin/gates/guards.sh"
printf '#!/usr/bin/env python3\nimport sys\nsys.exit(0)\n' >"$R/bin/gates/guards/nda-guard.py"; chmod +x "$R/bin/gates/guards/nda-guard.py"
for s in maker-guard.sh branch-guard.sh; do printf '#!/usr/bin/env bash\nexit 0\n' >"$R/bin/gates/guards/$s"; chmod +x "$R/bin/gates/guards/$s"; done
printf '#!/usr/bin/env bash\nexit 0\n' >"$R/bin/gates/branch-current.sh"; chmod +x "$R/bin/gates/branch-current.sh"
git init -q "$R" && g "$R" add -A >/dev/null 2>&1 && g "$R" -c core.hooksPath=/dev/null commit -qm "first" >/dev/null 2>&1
git init -q --bare "$T/remote.git"

# 1a — the install road the hook's own header names: core.hooksPath, not a copy
out="$(cd "$R" && bash bin/gates/guards/fixes-guard.sh --install 2>&1)"
[ "$(g "$R" config --get core.hooksPath)" = .githooks ] && ok "the install sets core.hooksPath = .githooks" \
  || bad "the install sets core.hooksPath = .githooks" "$out"
[ -e "$R/.git/hooks/pre-push" ] && bad "no dead copy is written under hooksPath" || ok "no dead copy is written under hooksPath"

# 1a2 — the pre-commit installer must not write over the TRACKED shipped hook
before="$(sha256sum "$R/.githooks/pre-commit" | cut -d' ' -f1)"
sout="$(cd "$R" && bash bin/gates/guards/secret-guard.sh --install 2>&1)"
after="$(sha256sum "$R/.githooks/pre-commit" | cut -d' ' -f1)"
[ "$before" = "$after" ] && ok "the pre-commit install leaves the tracked hook untouched under hooksPath" \
  || bad "the pre-commit install leaves the tracked hook untouched under hooksPath" "$sout"
case "$sout" in *'.githooks/pre-commit'*) ok "the pre-commit install says the shipped hook is already seated" ;; *) bad "the pre-commit install says the shipped hook is already seated" "$sout" ;; esac

# 1b — a push from a WORKTREE runs the wards (the fault was a hook that ran nothing, silently)
( cd "$R" && git worktree add -q "$T/wt" -b feat >/dev/null 2>&1 ) || bad "a worktree is created"
printf 'x\n' >"$T/wt/note.txt"
( cd "$T/wt" && g . add note.txt >/dev/null 2>&1 && g . -c core.hooksPath=/dev/null commit -qm "w" >/dev/null 2>&1 \
  && git remote add origin "$T/remote.git" && git push origin feat 2>&1 ) >"$T/push.out" 2>&1
grep -q 'WARD-RAN' "$T/push.out" && ok "the seated hook runs the wards from a worktree" \
  || bad "the seated hook runs the wards from a worktree" "$(tail -3 "$T/push.out")"

# 1c — the copy road: a copy in <git-dir>/hooks still resolves the PUSHING worktree, so it is not silent
C="$T/copy"; mkdir -p "$C/.git/hooks"
cp -R "$R/.pi" "$R/RULES" "$R/.githooks" "$R/bin" "$C/"
git init -q "$C" && g "$C" add -A >/dev/null 2>&1 && g "$C" -c core.hooksPath=/dev/null commit -qm "first" >/dev/null 2>&1
cp "$C/.githooks/pre-push" "$C/.git/hooks/pre-push"; chmod +x "$C/.git/hooks/pre-push"
printf 'y\n' >"$C/n2.txt"; g "$C" add n2.txt >/dev/null 2>&1 && g "$C" -c core.hooksPath=/dev/null commit -qm "c" >/dev/null 2>&1
( cd "$C" && git remote add origin "$T/remote.git" && git push origin HEAD:refs/heads/copy 2>&1 ) >"$T/push2.out" 2>&1
grep -q 'WARD-RAN' "$T/push2.out" && ok "a copied hook resolves its root and still runs the wards" \
  || bad "a copied hook resolves its root and still runs the wards" "$(tail -3 "$T/push2.out")"

# 1d — s_gates judges the INSTALL: hooksPath+shipped = green, a drifted copy = red, no hook = red
extract_fn "$EIR" _gates_hook >"$T/gates_fn.sh"
extract_fn "$EIR" _gates_shipped >>"$T/gates_fn.sh"
extract_fn "$EIR" s_gates >>"$T/gates_fn.sh"
judge() { ( cd "$1" && ROOT="$1" bash -c '. "$0"; s_gates' "$T/gates_fn.sh" ); }
judge "$R" && ok "s_gates is green where core.hooksPath seats the shipped hook" || bad "s_gates green under hooksPath"
D="$T/drift"; mkdir -p "$D/.githooks" "$D/.git/hooks"
cp "$ROOT/.githooks/pre-push" "$D/.githooks/pre-push"
printf '#!/usr/bin/env bash\nexit 0\n' >"$D/.git/hooks/pre-push"; chmod +x "$D/.git/hooks/pre-push"
git init -q "$D"
judge "$D" && bad "s_gates refuses a copy that is not the shipped hook" || ok "s_gates refuses a copy that is not the shipped hook"
cp "$D/.githooks/pre-push" "$D/.git/hooks/pre-push"
judge "$D" && ok "s_gates accepts a copy identical to .githooks/pre-push" || bad "s_gates accepts an identical copy"
rm -f "$D/.git/hooks/pre-push"
judge "$D" && bad "s_gates refuses a checkout with no hook installed" || ok "s_gates refuses a checkout with no hook installed"
grep -q "systemctl --user enable --now ratatoskr-relay" "$EIR" \
  && ok "the agentroad fault names the enable command" || bad "the agentroad fault names the enable command"

# 2. RUNTIMEPIN: a unit under the apps home is the APP's — never UNREGISTERED, never retargeted
printf 'runtimepin:\n'
P="$T/pin"; A="$T/apps"; U="$T/units"; H="$T/home"
mkdir -p "$P/RULES" "$P/bin/engine" "$P/.git" "$A/rodd/current" "$U" "$H" "$T/xdg"
cp "$ROOT/bin/engine/units.py" "$P/bin/engine/units.py"
printf '#!/usr/bin/env bash\nexit 0\n' >"$P/bin/engine/ymir-install.sh"; chmod +x "$P/bin/engine/ymir-install.sh"
printf '#!/usr/bin/env bash\necho start\n' >"$A/rodd/current/start.sh"; chmod +x "$A/rodd/current/start.sh"
printf 'x\n' >"$A/rodd/app.yaml"
cat >"$U/ymir-rodd.service" <<EOF
[Service]
Environment=YMIR_RUNTIME_DIR=$P
WorkingDirectory=$A/rodd/current
ExecStart=$A/rodd/current/start.sh
EOF
run_units() { YMIR_HOME="$H" YMIR_RUNTIME_DIR="$P" YMIR_UNIT_DIR="$U" YMIR_APPS_HOME="$A" \
  YMIR_UNITS_NO_ROLE_PROBE=1 YMIR_UNITS_ROLES=all XDG_DATA_HOME="$T/xdg" XDG_CONFIG_HOME="$T/xdg" \
  python3 "$UNITS" "$@"; }
chk="$(run_units check 2>&1)"
case "$chk" in
  *UNREGISTERED*) bad "an app's own unit is not UNREGISTERED" "$(printf '%s' "$chk" | grep -i rodd)" ;;
  *'"ymir-rodd","unit","ok","an app'"'"'s own unit, under the apps home"'*) ok "an app's own unit is judged ok, by name and reason" ;;
  *) bad "the ymir-rodd row is present and ok" "$chk" ;;
esac
wr="$(run_units write --dry-run 2>&1)"
case "$wr" in
  *'ymir-rodd","unregistered","app-owned"'*) ok "units.sh write leaves the app's own unit alone" ;;
  *'ymir-rodd'*) bad "units.sh write does not retarget the app's own unit" "$(printf '%s' "$wr" | grep -i rodd)" ;;
  *) bad "units.sh write names the app's own unit as app-owned" "$wr" ;;
esac
grep -q "app-path.sh" "$ROOT/bin/engine/units.py" && ok "the apps home is resolved through bin/apps/app-path.sh" \
  || bad "the apps home is resolved through bin/apps/app-path.sh"
extract_fn "$EIR" runtimepin_detail >"$T/runtimepin_fn.sh"
grep -q 'pin-refresh.sh' "$T/runtimepin_fn.sh" && ok "the runtimepin detail asks the pin's own verdict" \
  || bad "the runtimepin detail asks the pin's own verdict"

# 3. AGENTROAD: the mend writes the unit AND enables it — the row clears
printf 'agentroad:\n'
TR="$T/tree"; mkdir -p "$TR/bin/engine" "$TR/bin/agents" "$T/stub"
printf '#!/usr/bin/env bash\necho "$*" >>"%s/units.calls"\n' "$T" >"$TR/bin/engine/units.sh"; chmod +x "$TR/bin/engine/units.sh"
printf '#!/usr/bin/env bash\necho "$*" >>"%s/units.calls"\n' "$T" >"$T/stub/systemctl"; chmod +x "$T/stub/systemctl"
extract_fn "$EIR" f_agentroad >"$T/agentroad_fn.sh"
( SCRIPT_DIR="$TR/bin/agents" PATH="$T/stub:$PATH" bash -c '. "$0"; f_agentroad; echo "rc=$?"' "$T/agentroad_fn.sh" ) >"$T/agentroad.out" 2>&1
grep -q '^write ratatoskr-relay$' "$T/units.calls" 2>/dev/null && ok "the mend writes the relay's unit" \
  || bad "the mend writes the relay's unit" "$(cat "$T/units.calls" 2>/dev/null)"
grep -q -- '--user enable --now ratatoskr-relay' "$T/units.calls" 2>/dev/null && ok "the mend enables and starts the relay" \
  || bad "the mend enables and starts the relay" "$(cat "$T/units.calls" 2>/dev/null)"
awk '/name: agentroad/ { f=1 } f && /risk:/ { print; exit }' "$ROOT/config/surfaces.yaml" | grep -q 'safe' \
  && ok "the register calls agentroad a safe mend" || bad "the register calls agentroad a safe mend"

printf 'test_eir_true_mends: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
