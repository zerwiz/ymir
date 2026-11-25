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
export HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" XDG_DATA_HOME="$T/home/.local/share"   # allow-home-default: the test fences HOME in a temp dir
export YMIR_HOME="$T/ymirhome" YMIR_STATE_DIR="$T/state"
export YMIR_UNIT_DIR="$T/units" YMIR_APPLICATIONS_DIR="$T/apps-dir" YMIR_AUTOSTART_DIR="$T/autostart"
export YMIR_UNITS_NO_SYSTEMCTL=1 YMIR_UNITS_NO_ROLE_PROBE=1
unset YMIR_RUNTIME_DIR YMIR_RUNTIME_BRANCH YMIR_RUNTIME_UNITS YMIR_ROLE YMIR_UNITS_ROLES 2>/dev/null || true
mkdir -p "$HOME" "$YMIR_HOME/config" "$YMIR_UNIT_DIR" "$YMIR_APPLICATIONS_DIR" "$YMIR_AUTOSTART_DIR" "$T/state"
# plan 290 §3 — a unit is seated only where THIS machine's own file names its door
# (bin/forge/warden-policy.py). The fixture machine names them all on, because what these tests prove is
# the pin and the writer, never the policy; the policy has its own gate
# (bin/gates/tests/test_warden_lib.sh, CI gate `wardens-own-only`).
TEST_MACHINE="$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')"
mkdir -p "$YMIR_HOME/config/machines/$TEST_MACHINE"
{
  for d in queue-warden review-watch review-seat review-loop pr-watch issue-watch ship-watch \
           gna-mail snotra-mail git-sync private-scan; do
    printf '%s:\n  enabled: on\n' "$d"
  done
} >"$YMIR_HOME/config/machines/$TEST_MACHINE/wardens.yaml"
PIN="$HOME/ymir-runtime"
UNITS="$ROOT/bin/engine/units.sh"

# ── the fake origin: a small repo carrying exactly what the writer and the templates need ──────────
ORIGIN="$T/origin"
mkdir -p "$ORIGIN"
( cd "$ROOT" && git ls-files -co --exclude-standard -- \
    RULES bin/engine bin/forge/warden-policy.py .agents/config/units.yaml bin/vault/hoard-lib.sh \
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
# the launchers THIS tree ships templates for; an app that left for its own repo (2026-11-19) ships its own
for l in ymir-hlidskjalf ymir-smidja; do
  f="$YMIR_APPLICATIONS_DIR/$l.desktop"
  # plan 275 S11: a launcher runs the one stable command and names no tree at all — not the pin, not a worktree
  t "fresh seat: launcher $l.desktop runs ymir-app and names no tree" bash -c 'grep -q "^Exec=.*/ymir-app " "$1" && ! grep -q "^Exec=.*$0" "$1" && ! grep -q "^Exec=.*$2" "$1"' "$PIN" "$f" "$ROOT"
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
WT="$T/tree/.yggdrasil/hlidskjalf-every-screen"
cat >"$YMIR_APPLICATIONS_DIR/ymir-hlidskjalf.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=Hlidskjalf
Exec=$WT/apps/hlidskjalf/start.sh
Path=$WT/apps/hlidskjalf
DESK
t "launcher: check fails on a worktree launcher" bash -c '! bash "$0" check >/dev/null 2>&1' "$UNITS"
bash "$UNITS" write >/dev/null 2>&1
t "launcher: write turns it into the one stable command" grep -q "^Exec=.*/ymir-app hlidskjalf$" "$YMIR_APPLICATIONS_DIR/ymir-hlidskjalf.desktop"
t "launcher: and the worktree is gone from it" bash -c '! grep -q "yggdrasil" "$0"' "$YMIR_APPLICATIONS_DIR/ymir-hlidskjalf.desktop"

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

# 7b — the home is not a Ymir tree, even when it carries RULES/ and an installer (2026-11-25)
mkdir -p "$YMIR_HOME/RULES" "$YMIR_HOME/bin/engine"; touch "$YMIR_HOME/bin/engine/ymir-install.sh"
cat >"$YMIR_UNIT_DIR/hlidskjalf-gate.service" <<UNIT
[Service]
WorkingDirectory=$PIN/apps/hlidskjalf
EnvironmentFile=-$YMIR_HOME/.env.local
ExecStart=/usr/bin/env bun run server/index.ts
UNIT
out="$(bash "$UNITS" check 2>&1)"
t "home: an EnvironmentFile in the home is not OFF-PIN" bash -c '! grep -q "\"hlidskjalf-gate\",\"unit\",\"OFF-PIN\"" <<<"$0"' "$out"
t "home: the unit is judged on the pin and registered" grep -q '"hlidskjalf-gate","unit","ok"' <<<"$out"
cat >"$YMIR_UNIT_DIR/stray-home.service" <<UNIT
[Service]
ExecStart=/usr/bin/env some-tool --db $YMIR_HOME/hodd/memory/x.db
UNIT
out="$(bash "$UNITS" check 2>&1)"
t "home: a unit naming only the home is not a Ymir unit (no row)" bash -c '! grep -q "\"stray-home\"" <<<"$0"' "$out"
rm -f "$YMIR_UNIT_DIR/hlidskjalf-gate.service" "$YMIR_UNIT_DIR/stray-home.service"
t "register: heart-doors is registered, off the heart" grep -qE '^  - \{ name: heart-doors, +mode: adopt.*roles: \[forge, dev, hand\]' "$ROOT/config/units.yaml"

# 7c — the WRITE side: `units.sh write` must never rewrite a home path onto the pin. This is what happened on
#      2026-11-23 and 2026-11-25 (units-replaced.log): the home carried RULES/ and an installer, so every
#      line naming it (BROKK_ENV_FILE, MCP_GATEWAY_STATE, CMD_DB, the well's db, a drop-in) was retargeted
H="$HOME/Documents/ymirhome"     # under HOME, so the %h form the well's unit used is exercised too
mkdir -p "$H/RULES" "$H/bin/engine" "$H/config" "$YMIR_UNIT_DIR/nornir.service.d"; touch "$H/bin/engine/ymir-install.sh"
cp -r "$YMIR_HOME/config/machines" "$H/config/"
unit() { local f=$1; shift; { printf '[Service]\n'; printf '%s\n' "$@"; } >"$YMIR_UNIT_DIR/$f"; }   # <file> <line>…
unit bifrost.service "Environment=BROKK_ENV_FILE=$H/.env.local" "ExecStart=/bin/bash $PIN/bin/ward/x.sh"
unit mcp-gateway.service "Environment=MCP_GATEWAY_STATE=$H/state" "ExecStart=/bin/bash $PIN/bin/ward/x.sh"
unit nornir.service "Environment=BROKK_STATE_OVERRIDE=$H/state" "Environment=BROKK_CONFIG_OVERRIDE=$H/config" "ExecStart=/bin/bash $PIN/bin/ward/x.sh"
unit nornir.service.d/operator-home.conf "Environment=BROKK_CONFIG_OVERRIDE=$H/config"
unit smidja.service "Environment=CMD_DB=$H/smidja/smidja.db" "ExecStart=/bin/bash $PIN/bin/ward/x.sh"
unit well-mcp.service "ExecStart=%h/.fleet/mcp-proxy -- engram-mcp --db %h/Documents/ymirhome/hodd/memory/kaia.engram"
unit gna-desk.service "Environment=YMIR_HOME=$H" "ExecStart=/usr/bin/env python3 $PIN/bin/mail/gna_desk.py --port 8494"
unit hlidskjalf-gate.service "WorkingDirectory=$TREE" "EnvironmentFile=-$H/.env.local"
unit stray-home.service "ExecStart=/usr/bin/env some-tool --db $H/hodd/memory/x.db"
homed="bifrost.service mcp-gateway.service nornir.service nornir.service.d/operator-home.conf smidja.service well-mcp.service gna-desk.service stray-home.service"
before="$(cd "$YMIR_UNIT_DIR" && sha256sum $homed)"
YMIR_HOME="$H" bash "$UNITS" write >/dev/null 2>&1
t "home write: no unit naming only the home and the pin is rewritten" [ "$(cd "$YMIR_UNIT_DIR" && sha256sum $homed)" = "$before" ]
t "home write: the home's env file stays in the home" grep -qx "EnvironmentFile=-$H/.env.local" "$YMIR_UNIT_DIR/hlidskjalf-gate.service"
t "home write: a real working tree in the same unit still moves onto the pin" grep -qx "WorkingDirectory=$PIN" "$YMIR_UNIT_DIR/hlidskjalf-gate.service"
for f in $homed hlidskjalf-gate.service; do rm -f "$YMIR_UNIT_DIR/$f"; done
rm -rf "$H"

# 8 — the doors agree
t "Eir carries the runtimepin surface" grep -q 'runtimepin' "$ROOT/bin/agents/eir-doctor.sh"
t "install carries the runtime step and the sweep" bash -c 'grep -q "run_step step_runtime " "$0" && grep -q "run_step step_units " "$0"' "$ROOT/bin/engine/ymir-install.sh"
t "Gróa no longer skips a missing pin" bash -c '! grep -q "no pinned runtime configured (bin/engine/runtime-deploy.sh seats one)\\\\\\"\\"$" "$0" || grep -q "runtime-seat.sh" "$0"' "$ROOT/bin/agents/groa-update.sh"
t "runtime-deploy takes its units from the register" grep -q 'list --restart' "$ROOT/bin/engine/runtime-deploy.sh"
t "no unit writer left names the tree it ran from" bash -c '! grep -nE "WorkingDirectory=\$ROOT|ExecStart=.*\$ROOT/bin" "$0"/bin/mail/install.sh "$0"/bin/forge/{issue-watch,queue-warden,review-watch,ship-watch,pr-watch,review-seat,review-shelf}.sh' "$ROOT"

printf 'test_units: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
