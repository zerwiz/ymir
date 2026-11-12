#!/usr/bin/env bash
# test_units.sh — plan 269: every Ymir service and app runs from the pinned runtime, from the first
# install, and all of them are one system (config/units.yaml + bin/engine/units.sh).
#
#   1. no pin: a unit is refused with the remedy named, and nothing is written
#   2. a fresh seat (runtime-seat.sh) clones the pin, records runtime.env, and leaves EVERY unit and
#      launcher on it — gna-desk and the forge timers rendered, all six launchers pointing at the pin
#   3. the seat is idempotent: a second run changes nothing and never rewrites an operator's line
#   4. a planted unit on a working tree is FOUND (check, exit 1) and REWRITTEN (write), old line logged
#   5. a launcher that points into an errand worktree is rewritten to the pin
#   6. a unit written by the code in a worktree names the pin, never the worktree
#   7. an app that ships a launcher template joins by adding it — nothing else is edited
#   8. Gróa's / Eir's doors exist and agree (surface registered, step registered)
#
# Everything runs in a temp HOME with a fake systemd directory: no real unit is read, written or
# restarted, and nothing is pushed anywhere.
set -uo pipefail
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
pass=0; fail=0
t() { local name=$1; shift; if "$@"; then printf '  ok   %s\n' "$name"; pass=$((pass+1)); else printf '  FAIL %s\n' "$name"; fail=$((fail+1)); fi; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" XDG_DATA_HOME="$T/home/.local/share"
export YMIR_HOME="$T/ymirhome" YMIR_STATE_DIR="$T/state"
export YMIR_UNIT_DIR="$T/units" YMIR_APPLICATIONS_DIR="$T/apps-dir" YMIR_AUTOSTART_DIR="$T/autostart"
export YMIR_UNITS_NO_SYSTEMCTL=1 YMIR_UNITS_NO_ROLE_PROBE=1
unset YMIR_RUNTIME_DIR YMIR_RUNTIME_BRANCH YMIR_RUNTIME_UNITS YMIR_ROLE YMIR_UNITS_ROLES 2>/dev/null || true
mkdir -p "$HOME" "$YMIR_HOME/config" "$YMIR_UNIT_DIR" "$YMIR_APPLICATIONS_DIR" "$YMIR_AUTOSTART_DIR" "$T/state"
PIN="$HOME/ymir-runtime"
UNITS="$ROOT/bin/engine/units.sh"

# ── the fake origin: a small repo carrying exactly what the writer and the templates need ──────────
ORIGIN="$T/origin"
mkdir -p "$ORIGIN"
( cd "$ROOT" && git ls-files -co --exclude-standard -- \
    RULES bin/engine .agents/config/units.yaml bin/vault/hoard-lib.sh \
    'apps/*/electron/*.in' 'apps/sessrumnir/resources/*.in' \
    apps/bilskirnir/start.sh apps/rodd/start.sh scripts/electron.sh bin/desktop/sessrumnir-launch.sh \
  | while IFS= read -r f; do [ -e "$f" ] && { mkdir -p "$ORIGIN/$(dirname "$f")"; cp -p "$f" "$ORIGIN/$f"; }; done )
ln -s .agents/config "$ORIGIN/config"   # config/ is a symlink to .agents/config in the real tree
mkdir -p "$ORIGIN/apps/hlidskjalf" "$ORIGIN/bin/desktop" "$ORIGIN/scripts"
touch "$ORIGIN/scripts/electron.sh" "$ORIGIN/bin/desktop/sessrumnir-launch.sh"
mkdir -p "$ORIGIN/apps/rodd" "$ORIGIN/apps/bilskirnir"; touch "$ORIGIN/apps/rodd/start.sh" "$ORIGIN/apps/bilskirnir/start.sh"
# a NEW app: nothing but its own launcher template and its door (check 7)
mkdir -p "$ORIGIN/apps/newapp/electron"
cat >"$ORIGIN/apps/newapp/electron/ymir-newapp.desktop.in" <<'DESK'
[Desktop Entry]
Type=Application
Name=Ymir · Newapp
Exec=__YMIR_ROOT__/apps/newapp/start.sh
Path=__YMIR_ROOT__/apps/newapp
Terminal=false
DESK
touch "$ORIGIN/apps/newapp/start.sh"
git -C "$ORIGIN" init -q -b main && git -C "$ORIGIN" add -A && \
  git -C "$ORIGIN" -c user.name=t -c user.email=t@t commit -q -m seed

# 1 — no pin yet
out="$(bash "$UNITS" write gna-desk 2>&1)"; rc=$?
t "no pin: a render is refused (exit 1)" [ "$rc" -eq 1 ]
t "no pin: the refusal names the remedy" grep -q 'runtime-seat.sh' <<<"$out"
t "no pin: nothing was written" [ -z "$(ls -A "$YMIR_UNIT_DIR")" ]

# 2 — a fresh seat
# a stray the first install left behind: a unit seated from a working tree (before the pin existed)
TREE="$T/tree"; mkdir -p "$TREE/RULES" "$TREE/bin/engine" "$TREE/bin/ward"; touch "$TREE/bin/engine/ymir-install.sh" "$TREE/bin/ward/x.sh"
out="$(YMIR_RUNTIME_SOURCE="$ORIGIN" bash "$ROOT/bin/engine/runtime-seat.sh" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] || printf "%s\n" "$out" | head -20 >&2
t "fresh seat: exit 0" [ "$rc" -eq 0 ]
t "fresh seat: the pin is a git checkout on main" [ "$(git -C "$PIN" rev-parse --abbrev-ref HEAD 2>/dev/null)" = main ]
t "fresh seat: runtime.env records the pin" grep -qE '^YMIR_RUNTIME_DIR="\$HOME/ymir-runtime"' "$YMIR_HOME/config/runtime.env"
t "fresh seat: gna-desk is written, from the pin" grep -q "^ExecStart=/usr/bin/env python3 $PIN/bin/mail/gna_desk.py --port 8494" "$YMIR_UNIT_DIR/gna-desk.service"
t "fresh seat: the forge clocks are written" [ -f "$YMIR_UNIT_DIR/queue-warden.timer" ] && [ -f "$YMIR_UNIT_DIR/review-loop.timer" ] && [ -f "$YMIR_UNIT_DIR/pr-watch.service" ]
t "fresh seat: no unit names the tree the seat ran from" bash -c '! grep -rl -e "$0" -e "$1" "$2" >/dev/null' "$ROOT" "$TREE" "$YMIR_UNIT_DIR"
for l in rodd ymir-bilskirnir ymir-hlidskjalf ymir-odrerir ymir-sessrumnir ymir-smidja; do
  f="$YMIR_APPLICATIONS_DIR/$l.desktop"
  t "fresh seat: launcher $l.desktop points at the pin" bash -c 'grep -q "^Exec=.*$0" "$1" && ! grep -q "^Exec=.*$2" "$1"' "$PIN" "$f" "$ROOT"
done
bash "$UNITS" check 2>&1 | grep -v '"ok"\|absent\|^units' >&2
t "fresh seat: check agrees (exit 0)" bash -c 'bash "$0" check >/dev/null' "$UNITS"

# 3 — idempotent, and an operator's own record is never rewritten
printf '# mine\nYMIR_RUNTIME_BRANCH="main"\n' >>"$YMIR_HOME/config/runtime.env"
before="$(cat "$YMIR_HOME/config/runtime.env")"
sum1="$(cd "$YMIR_UNIT_DIR" && cat -- * | cksum)"
out="$(YMIR_RUNTIME_SOURCE="$ORIGIN" bash "$ROOT/bin/engine/runtime-seat.sh" 2>&1)"; rc=$?
t "seat twice: exit 0" [ "$rc" -eq 0 ]
t "seat twice: runtime.env keeps one pin line and the operator's own" [ "$(grep -c '^YMIR_RUNTIME_DIR=' "$YMIR_HOME/config/runtime.env")" = 1 ] && grep -q '^# mine' "$YMIR_HOME/config/runtime.env"
t "seat twice: runtime.env only ever grew" [ "$(wc -l <"$YMIR_HOME/config/runtime.env")" -ge "$(wc -l <<<"$before")" ]
t "seat twice: not one unit changed" [ "$(cd "$YMIR_UNIT_DIR" && cat -- * | cksum)" = "$sum1" ]

# 4 — a planted unit on a working tree
cat >"$YMIR_UNIT_DIR/planted.service" <<UNIT
[Service]
WorkingDirectory=$TREE
ExecStart=/bin/bash $TREE/bin/ward/x.sh
UNIT
cat >"$YMIR_UNIT_DIR/mimir.service" <<'UNIT'
[Service]
WorkingDirectory=%h/tree
ExecStart=/bin/bash %h/tree/bin/ward/x.sh --foreground
UNIT
ln -s "$T/tree" "$HOME/tree"
out="$(bash "$UNITS" check 2>&1)"; rc=$?
t "planted: check fails (exit 1)" [ "$rc" -eq 1 ]
t "planted: check names the stray" grep -q '"planted","unit","OFF-PIN"' <<<"$out"
t "planted: check names the adopted one in %h form" grep -q '"mimir","unit","OFF-PIN"' <<<"$out"
out="$(bash "$UNITS" write 2>&1)"
t "planted: write moves the planted unit onto the pin" grep -q "^ExecStart=/bin/bash $PIN/bin/ward/x.sh" "$YMIR_UNIT_DIR/planted.service"
t "planted: write moves the register's unit, %h form included" grep -q "^ExecStart=/bin/bash $PIN/bin/ward/x.sh --foreground" "$YMIR_UNIT_DIR/mimir.service"
t "planted: the old line is logged, not lost" grep -q "ExecStart=/bin/bash $TREE/bin/ward/x.sh" "$YMIR_STATE_DIR/units-replaced.log"
t "planted: an unregistered unit is called out" grep -q '"planted","unregistered","UNREGISTERED"' <<<"$out"
out="$(bash "$UNITS" check 2>&1)"; rc=$?
t "planted: after the move only the missing register entry remains (exit 1)" [ "$rc" -eq 1 ] && grep -q '"planted","unit","UNREGISTERED"' <<<"$out" && ! grep -q 'OFF-PIN' <<<"$out"
rm -f "$YMIR_UNIT_DIR/planted.service"
t "planted: with the register honoured, check is clean again" bash -c 'bash "$0" check >/dev/null' "$UNITS"

# 4b — the tree's name is a PREFIX of the pin's ($HOME/ymir vs $HOME/ymir-runtime): a root matches as a
#      whole path component only, a unit on the pin is left alone, and a second run changes nothing
mkdir -p "$HOME/ymir/RULES" "$HOME/ymir/bin/engine" "$YMIR_UNIT_DIR/prefixed.service.d"; touch "$HOME/ymir/bin/engine/ymir-install.sh"
cat >"$YMIR_UNIT_DIR/prefixed.service" <<UNIT
[Service]
WorkingDirectory=$HOME/ymir/systems/skirnir
ExecStart=/bin/bash $HOME/ymir/bin/ward/x.sh
UNIT
cat >"$YMIR_UNIT_DIR/onpin.service" <<UNIT
[Service]
WorkingDirectory=$PIN/systems/skirnir
ExecStart=/bin/bash $PIN/bin/ward/x.sh
UNIT
cat >"$YMIR_UNIT_DIR/prefixed.service.d/10-env.conf" <<UNIT
[Service]
WorkingDirectory=$HOME/ymir/systems/skirnir
UNIT
cp "$YMIR_UNIT_DIR/onpin.service" "$T/onpin.before"
bash "$UNITS" write >/dev/null 2>&1
t "prefix: a unit on the working tree moves once onto the pin" grep -qx "WorkingDirectory=$PIN/systems/skirnir" "$YMIR_UNIT_DIR/prefixed.service"
t "prefix: the path is never doubled (ymir-runtime-runtime)" bash -c '! grep -rq "ymir-runtime-runtime" "$0"' "$YMIR_UNIT_DIR"
t "prefix: ExecStart moved once too" grep -qx "ExecStart=/bin/bash $PIN/bin/ward/x.sh" "$YMIR_UNIT_DIR/prefixed.service"
t "prefix: a drop-in is moved once" grep -qx "WorkingDirectory=$PIN/systems/skirnir" "$YMIR_UNIT_DIR/prefixed.service.d/10-env.conf"
t "prefix: a unit already on the pin is unchanged" cmp -s "$T/onpin.before" "$YMIR_UNIT_DIR/onpin.service"
sums1="$(cd "$YMIR_UNIT_DIR" && find . -type f -exec sha256sum {} + | sort)"
bash "$UNITS" write >/dev/null 2>&1
sums2="$(cd "$YMIR_UNIT_DIR" && find . -type f -exec sha256sum {} + | sort)"
t "prefix: a second write changes nothing" [ "$sums1" = "$sums2" ]
rm -rf "$HOME/ymir"

# 5 — a launcher pointing into an errand worktree
WT="$T/tree/.yggdrasil/bilskirnir-every-screen"
cat >"$YMIR_APPLICATIONS_DIR/ymir-bilskirnir.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=Bilskirnir
Exec=$WT/apps/bilskirnir/start.sh
Path=$WT/apps/bilskirnir
DESK
t "launcher: check fails on a worktree launcher" bash -c '! bash "$0" check >/dev/null 2>&1' "$UNITS"
bash "$UNITS" write >/dev/null 2>&1
t "launcher: write points it at the pin" grep -q "^Exec=$PIN/apps/bilskirnir/start.sh" "$YMIR_APPLICATIONS_DIR/ymir-bilskirnir.desktop"
t "launcher: and the worktree is gone from it" bash -c '! grep -q "yggdrasil" "$0"' "$YMIR_APPLICATIONS_DIR/ymir-bilskirnir.desktop"

# 6 — written by the code in a worktree, a unit still names the pin
rm -f "$YMIR_UNIT_DIR/gna-desk.service"
bash "$ROOT/bin/engine/units.sh" write gna-desk >/dev/null 2>&1
t "worktree writer: gna-desk names the pin" grep -q "^ExecStart=.* $PIN/bin/mail/gna_desk.py" "$YMIR_UNIT_DIR/gna-desk.service"
t "worktree writer: it never names the tree it ran from" bash -c '! grep -q "$0" "$1"' "$ROOT" "$YMIR_UNIT_DIR/gna-desk.service"
t "worktree writer: --set carries a seat's own port" bash -c 'bash "$0" write gna-desk --set GNA_DESK_PORT=9123 >/dev/null 2>&1; grep -q "port 9123" "$1"' "$UNITS" "$YMIR_UNIT_DIR/gna-desk.service"
t "worktree writer: review-seat takes its clone and the helm flag" bash -c 'bash "$0" write review-seat --set CLONE=/srv/clone --set "PRIMARY= --primary" >/dev/null 2>&1; grep -q "ensure --clone /srv/clone --primary" "$1" && grep -q "^WorkingDirectory=/srv/clone" "$1"' "$UNITS" "$YMIR_UNIT_DIR/review-seat.service"

# 7 — a new app joins by shipping its template
out="$(YMIR_RUNTIME_DIR="$PIN" bash "$PIN/bin/engine/units.sh" list 2>&1)"
t "discovery: the new app is listed from apps/*, no hand list" grep -q '"newapp","ymir-newapp.desktop"' <<<"$out"
YMIR_RUNTIME_DIR="$PIN" bash "$PIN/bin/engine/units.sh" write >/dev/null 2>&1
t "discovery: and its launcher is written against the pin" grep -q "^Exec=$PIN/apps/newapp/start.sh" "$YMIR_APPLICATIONS_DIR/ymir-newapp.desktop"
missing=""; for d in $(ls "$ROOT/apps" | grep -v '\.md$'); do bash "$UNITS" list | sed -n '/^apps\[/,$p' | grep -q "^  \"$d\"," || missing="$missing $d"; done
t "discovery: every directory under apps/ is accounted for (missing:${missing:- none})" [ -z "$missing" ]

# 8 — the doors agree
t "Eir carries the runtimepin surface" grep -q 'runtimepin' "$ROOT/bin/agents/eir-doctor.sh"
t "install carries the runtime step and the sweep" bash -c 'grep -q "run_step step_runtime " "$0" && grep -q "run_step step_units " "$0"' "$ROOT/bin/engine/ymir-install.sh"
t "Gróa no longer skips a missing pin" bash -c '! grep -q "no pinned runtime configured (bin/engine/runtime-deploy.sh seats one)\\\\\\"\\"$" "$0" || grep -q "runtime-seat.sh" "$0"' "$ROOT/bin/agents/groa-update.sh"
t "runtime-deploy takes its units from the register" grep -q 'list --restart' "$ROOT/bin/engine/runtime-deploy.sh"
t "no unit writer left names the tree it ran from" bash -c '! grep -nE "WorkingDirectory=\$ROOT|ExecStart=.*\$ROOT/bin" "$0"/bin/mail/install.sh "$0"/bin/forge/{issue-watch,queue-warden,review-watch,ship-watch,pr-watch,review-seat,review-shelf}.sh' "$ROOT"

printf 'test_units: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
