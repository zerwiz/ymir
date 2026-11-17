#!/usr/bin/env bash
# test_launchd_step_skips.sh — the macOS service step skips cleanly on Linux, and never silently (plan 293).
#
# `bin/engine/ymir-install.sh` step_launchd is the install step that seats `systemctl --user` on a Mac.
# Nothing tested it, so nothing noticed if it vanished from the chain, or if it ever reported FAIL on a
# host that owes no launchd at all (RULES/05: a clean skip is a pass, and it must SAY why).
#
# Every case runs a copy of the real function, extracted from the real installer, under stubs — no Mac,
# no install, and the fake HOME keeps the door's own writes out of the operator's seats.
#
#   1. the door on Linux: check/ensure/remove all answer 0 with its named SKIP line, and write nothing
#   2. step_launchd on Linux: the row is launchd|SKIP with its named detail, in a check run and a real run
#   3. step_launchd on a Mac (fake uname): it seats the shim, reports OK, and is idempotent — never SKIP
#   4. the step is WIRED: `run_step step_launchd` is in the chain, after the runtime step
# Exit: 0 every case held · 1 a case failed.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
INSTALL="$ROOT/bin/engine/ymir-install.sh"
DOOR="$ROOT/bin/engine/launchd-ensure.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

LINUX_LINE='"launchd","SKIP","not a Mac — systemd is the service manager here"'
STEP_LINE='"launchd","SKIP","not a Mac — systemd runs the units here"'

# ── 1. the door itself ───────────────────────────────────────────────────────
for verb in check ensure remove; do
  out="$(bash "$DOOR" "$verb" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && ok "launchd-ensure.sh $verb is a clean skip (exit 0)" || bad "launchd-ensure.sh $verb exited $rc: $out"
  case "$out" in
    *"$LINUX_LINE"*) ok "launchd-ensure.sh $verb names why it skipped" ;;
    *) bad "launchd-ensure.sh $verb did not print its named line: $out" ;;
  esac
done

# ── the step, extracted from the real installer ──────────────────────────────
step_src="$T/step.sh"
sed -n '/^step_launchd() {/,/^}/p' "$INSTALL" > "$step_src"
if [ -s "$step_src" ] && grep -q '^step_launchd() {' "$step_src"; then
  ok "step_launchd is found in bin/engine/ymir-install.sh"
else
  bad "step_launchd is no longer a function in bin/engine/ymir-install.sh"
  printf '\n%s\n' "a suite failed"; exit 1
fi

# harness <fake-home> [env …] — run the extracted step and print its rows as id|state|detail.
harness() {
  local home="$1"; shift
  cat > "$T/harness.sh" <<HARNESS
#!/usr/bin/env bash
set -u
SCRIPT_DIR="$ROOT/bin/engine"
CHECK="\${CHECK:-0}"
IDS=(); STATUS=(); DETAIL=()
add() { IDS+=("\$1"); STATUS+=("\$2"); DETAIL+=("\$3"); }
. "$step_src"
step_launchd
for i in "\${!IDS[@]}"; do printf '%s|%s|%s\n' "\${IDS[\$i]}" "\${STATUS[\$i]}" "\${DETAIL[\$i]}"; done
HARNESS
  env -i HOME="$home" PATH="${PATH_FOR_STEP:-$PATH}" CHECK="${STEP_CHECK:-0}" "${@}" bash "$T/harness.sh" 2>&1
}

# ── 2. on Linux: the named skip, in both the check run and a real run ────────
for check in 0 1; do
  rows="$(STEP_CHECK="$check" harness "$T/home-linux")"
  case "$rows" in
    "launchd|SKIP|not a Mac — systemd runs the units here") ok "step_launchd (CHECK=$check) clean-skips on Linux with its named line" ;;
    *) bad "step_launchd (CHECK=$check) gave '$rows', not the named SKIP row" ;;
  esac
done
[ -e "$T/home-linux/.local/bin/systemctl" ] && bad "step_launchd seated a systemctl shim on Linux" \
                                           || ok "step_launchd seats nothing on Linux"

# ── 3. on a Mac: the step seats the shim, reports OK, and is idempotent ─────
# `uname` is stubbed to say Darwin and the PATH carries only the stubs, so a real /usr/bin/systemctl
# cannot shadow the layer — the seating road the Mac actually takes is the one exercised.
stub="$T/stub"; mkdir -p "$stub"
printf '#!/bin/sh\nprintf Darwin\\n' > "$stub/uname"; chmod +x "$stub/uname"
for tool in bash python3 chmod mkdir ln readlink dirname basename cat grep cut sed tr; do
  p="$(command -v "$tool" 2>/dev/null)" && ln -s "$p" "$stub/$tool" 2>/dev/null
done
mac_home="$T/home-mac"; mkdir -p "$mac_home"
PATH_FOR_STEP="$stub" rows="$(harness "$mac_home" YMIR_SHORTCUT_BIN="$mac_home/.local/bin")"
case "$rows" in
  "launchd|OK|seated: systemctl --user -> launchd ($mac_home/.local/bin/systemctl -> $ROOT/bin/engine/launchd-user.py)")
    ok "on a Mac step_launchd seats systemctl --user as launchd" ;;
  *) bad "on a Mac step_launchd gave '$rows'" ;;
esac
[ -L "$mac_home/.local/bin/systemctl" ] && [ -L "$mac_home/.local/bin/systemd-run" ] \
  && ok "the shim and the systemd-run name both point at launchd-user.py" \
  || bad "the shims were not linked in the fake home"
case "$rows" in *SKIP*) bad "on a Mac the step reported SKIP" ;; *) ok "on a Mac the step never reports the skip" ;; esac

again="$(PATH_FOR_STEP="$stub" STEP_CHECK=1 harness "$mac_home" YMIR_SHORTCUT_BIN="$mac_home/.local/bin")"
[ "$again" = "launchd|OK|systemctl --user is answered by launchd" ] \
  && ok "a second, --check run reads the seat back as answered by launchd" \
  || bad "a second run gave '$again'"

# ── 4. the step is wired into the chain ─────────────────────────────────────
grep -qE '^run_step step_launchd ' "$INSTALL" \
  && ok "step_launchd is called by run_step in the install chain" \
  || bad "step_launchd is defined but never run — the layer would never be seated"
awk '/^run_step step_runtime /{r=NR} /^run_step step_launchd /{l=NR} END{exit !(r && l && l>r)}' "$INSTALL" \
  && ok "the step runs after the runtime step (it seats a pointer at the pin)" \
  || bad "step_launchd does not run after step_runtime"

printf '\n%s\n' "$([ "$fail" -eq 0 ] && echo 'all cases held' || echo 'a case failed')"
exit "$fail"
