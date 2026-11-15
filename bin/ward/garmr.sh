#!/usr/bin/env bash
# garmr.sh — GARMR, the hound at the gate: the door to Ymir's guardian.
#
#   garmr.sh status              # what is armed, what is running, OFF or ON
#   garmr.sh off | on            # the ONE switch: turn the guardian off, and back on  [root]
#   garmr.sh install [--dry-run] # arm the senses (auditd) and seat the two units  [root]
#   garmr.sh start|stop|restart  # the hound (system) and the brain (user)
#   garmr.sh judge [--dry-run]   # run the judgement once, now
#   garmr.sh tail [N]            # the newest findings, judged, HIGH and CRITICAL first
#   garmr.sh once                # one sense pass (listeners/egress + audit so far)
#   garmr.sh verify              # prove the guardian is not silently dead
#
# Garmr notices, Vörðr judges in his report, Gná speaks, Runes keeps the record.
# He is read-only against the machine: he never closes a door, never kills a process.
#
# Exit: 0 ok · 1 a finding above the floor, or a broken surface · 2 usage.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GARMR="$ROOT/bin/ward/garmr"
PY="$(command -v python3 || echo /usr/bin/python3)"
# plan 272, fault 12: a unit is settled through the register, whichever tree this script runs from.
[ -r "$SCRIPT_DIR/../engine/unit-settle-lib.sh" ] && . "$SCRIPT_DIR/../engine/unit-settle-lib.sh"

# the usage is the header itself, read until the first line that is not a comment,
# so adding a verb can never print `set -u` as if it were help (it did).
usage() { awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; }

# Under sudo, HOME is root's and the hoard cannot resolve: adopt the operator's.
RUN_UID="${SUDO_UID:-$(id -u)}"
if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
  RUN_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  [ -n "$RUN_HOME" ] && export HOME="$RUN_HOME"
fi
as_operator() {  # run a command as the operator, with their session bus
  if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    sudo -u "$SUDO_USER" XDG_RUNTIME_DIR="/run/user/$RUN_UID" "$@"
  else
    "$@"
  fi
}

cmd="${1:-status}"; shift || true
dry=0
for a in "$@"; do
  case "$a" in
    --dry-run) dry=1 ;;
    -h|--help) usage; exit 0 ;;
    --version|-v) printf '%s\n' "$VERSION"; exit 0 ;;
  esac
done

hoard() {
  local lib="$ROOT/bin/vault/hoard-lib.sh" home=""
  if [ -r "$lib" ]; then
    # shellcheck disable=SC1090
    . "$lib" >/dev/null 2>&1 || true
    command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root home
  fi
  if [ -z "$home" ] && [ -n "${YMIR_HOME:-}" ]; then home="$YMIR_HOME"; fi
  if [ -z "$home" ]; then
    printf 'error: the hoard is unresolved — set YMIR_HOME, or run from a checkout\n' >&2
    printf 'help: bin/vault/hoard-lib.sh must be able to answer\n' >&2
    exit 2
  fi
  printf '%s' "$home"
}
HOME_DIR="$(hoard)"
STATE="$HOME_DIR/hodd/state/garmr"
FINDINGS="/var/log/ymir/garmr/findings.jsonl"
AUDIT_LOG="/var/log/audit/audit.log"
# THE SWITCH has one authority and one readable copy. The authority is ROOT's marker, so no
# ordinary process can silence the hound; the copy is the surfaces' REPORT, because Hlidskjalf
# and housewatch read the HOME and a root-only path left them saying "all clear" over a paused
# hound. The copy is never the gate: a file the operator can write must not be able to silence
# a guardian, or it is a switch the intruder flips first.
MARKER="/var/log/ymir/garmr/PAUSED"
MIRROR="$STATE/PAUSED"

is_off() { [ -f "$MARKER" ]; }                      # the gate: root's word only
reports_off() { [ -f "$MARKER" ] || [ -f "$MIRROR" ]; }   # what the surfaces may say

write_mirror() {  # <text> — the operator-readable copy of root's word
  mkdir -p "$STATE" 2>/dev/null || return 0
  printf '%s\n' "$1" > "$MIRROR" 2>/dev/null || return 0
  chmod 0644 "$MIRROR" 2>/dev/null || true
  if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    chown "$SUDO_USER:" "$MIRROR" 2>/dev/null || true
  fi
}

mode_text() {
  if reports_off; then
    local since
    since="$(cat "$MARKER" 2>/dev/null || cat "$MIRROR" 2>/dev/null || echo unknown)"
    printf 'OFF (since %s) — the units are disabled, so a reboot will not raise him' "$since"
  else
    printf 'ON — watching'
  fi
}

# ONE file holds the rules, so a reboot cannot disarm the house (Rule 24).
rules_text() {
  local home="$1"
  # Whose ~/.ssh is watched: the operator's, never root's. `sudo bash garmr.sh install`
  # — the house's own advice — runs with HOME=/root, so $HOME pointed the one watch
  # that witnesses a key being added at /root/.ssh/authorized_keys, which does not
  # exist. SUDO_USER is who actually asked.
  local _op_home=""
  if [ -n "${SUDO_USER:-}" ]; then
    _op_home="$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6)"
  fi
  [ -n "$_op_home" ] || _op_home="$HOME"
  # QUOTED heredoc: the block carries explanatory backticks (`a1`, `a2`, `pidfd_send_signal`),
  # and unquoted they were command substitution — every install printed "a1: command not
  # found" and blanked the very comment that explains the rules. Nothing here needs to
  # expand, and the one watch that wanted $home below is emitted after the block.
  cat <<'RULES'
# Ymir — Garmr's senses. Installed by bin/ward/garmr.sh install. Runtime-only
# rules vanish at reboot; this file is what brings them back.
#
# -D FIRST, or the unit can never be restarted: garmr.sh primes these same rules with
# auditctl line by line, and augenrules then refuses every one of them with "Error
# sending add rule data request (Rule exists)" — so `audit-rules.service` failed even
# with a correct file, and the green state was unreachable by design.
-D
-b 8192
-a always,exit -F arch=b64 -S execve -F auid>=1000 -F auid!=unset -k ymir-exec
# THE SIGNAL THAT ENDS A BROWSER, in every way it can arrive (fixed 2026-10-31).
# The two rules that stood here filtered `a1`, which is right for kill(2) and tkill(3) but WRONG for
# tgkill(2): there the signal is `a2` and `a1` is the TID, so `-F a1=9` matched when a thread id was 9 —
# i.e. never. And `pidfd_send_signal` (what systemd uses to kill a unit's processes) and the
# `rt_*sigqueueinfo` pair were not watched at all. Eleven browser deaths left no witness; this is why.
-a always,exit -F arch=b64 -S kill -F a1=15 -k ymir-browserkill
-a always,exit -F arch=b64 -S kill -F a1=9 -k ymir-browserkill
-a always,exit -F arch=b64 -S tkill -F a1=15 -k ymir-browserkill
-a always,exit -F arch=b64 -S tkill -F a1=9 -k ymir-browserkill
-a always,exit -F arch=b64 -S tgkill -F a2=15 -k ymir-browserkill
-a always,exit -F arch=b64 -S tgkill -F a2=9 -k ymir-browserkill
-a always,exit -F arch=b64 -S rt_sigqueueinfo -F a1=15 -k ymir-browserkill
-a always,exit -F arch=b64 -S rt_sigqueueinfo -F a1=9 -k ymir-browserkill
-a always,exit -F arch=b64 -S rt_tgsigqueueinfo -F a2=15 -k ymir-browserkill
-a always,exit -F arch=b64 -S rt_tgsigqueueinfo -F a2=9 -k ymir-browserkill
-a always,exit -F arch=b64 -S pidfd_send_signal -F a1=15 -k ymir-browserkill
-a always,exit -F arch=b64 -S pidfd_send_signal -F a1=9 -k ymir-browserkill
RULES
  # ── every watch below is guarded by the path's own existence ──────────────
  # auditd refuses the ENTIRE ruleset with ENOENT — "Error sending add rule data
  # request (No such file or directory)" — when a -w names a path that is not
  # there, and then the house runs with no rules at all, silently, saying only
  # `Failed to start Load Audit Rules` in the journal. That is what happened on
  # 2026-11-04: two watches named paths this seat does not have (the hoard has no
  # .ssh/, and this is a systemd box with no cron spool), so nothing was armed and
  # auditd had burnt 11s of CPU policing an empty ruleset. Guarded, and the real
  # key file — $HOME/.ssh/authorized_keys, where the fleet keys actually live — is
  # watched as well as the hoard's, if a seat has one there.
  for p in /etc/passwd /etc/shadow /etc/group /etc/sudoers /etc/sudoers.d; do
    [ -e "$p" ] && printf -- '-w %s -p wa -k ymir-identity\n' "$p"
  done
  for p in "$_op_home/.ssh/authorized_keys" "$home/.ssh/authorized_keys"; do
    [ -e "$p" ] && printf -- '-w %s -p wa -k ymir-identity\n' "$p"
  done
  for p in /etc/systemd/system /etc/systemd/user /etc/cron.d /etc/crontab /var/spool/cron; do
    [ -e "$p" ] && printf -- '-w %s -p wa -k ymir-persist\n' "$p"
  done
  for dir in "$home/hodd/data/snotra" "$home/hodd/evidence" "$home/hodd/life/meetings" \
             "$home/hodd/memory/snotra" "$home/hodd/secrets"; do
    [ -d "$dir" ] && printf -- '-w %s -p wa -k ymir-sensitive\n' "$dir"
  done
  # persistence in the operator's own tree: a unit or an autostart entry added here
  for dir in "$home/.config/autostart" "$home/.config/systemd/user"; do
    [ -d "$dir" ] && printf -- '-w %s -p wa -k ymir-persist\n' "$dir"
  done
}

arm_senses() {
  local sensitive=(
    "$HOME_DIR/hodd/data/snotra"
    "$HOME_DIR/hodd/evidence"
    "$HOME_DIR/hodd/life/meetings"
    "$HOME_DIR/hodd/memory/snotra"
    "$HOME_DIR/hodd/secrets"
  )
  local run=(sudo)
  [ "$dry" = 1 ] && run=(echo "would run:")
  "${run[@]}" mkdir -p /var/log/ymir/garmr
  rules_text "$HOME_DIR" | "${run[@]}" tee /etc/audit/rules.d/ymir.rules >/dev/null
  # `auditctl -R` aborts on the first rule that already exists, so each line is
  # loaded on its own and an existing rule is not an error. augenrules does the
  # same job properly when the package ships it.
  if command -v augenrules >/dev/null 2>&1; then
    "${run[@]}" augenrules --load >/dev/null 2>&1 || true
  fi
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    # shellcheck disable=SC2086
    "${run[@]}" auditctl $line >/dev/null 2>&1 || true
  done < /etc/audit/rules.d/ymir.rules
}

seat_units() {
  local render="$SCRIPT_DIR/../../tools/mill/systemd"
  # OFF is a standing word, not a moment: while the marker stands, a refresh may re-render
  # the units but must never enable or start them — otherwise Groa, install, or a reboot
  # quietly raises a guardian the Allfather put down (and it did, every update).
  local off=0; is_off && off=1
  # The units must run the PINNED runtime, never the checkout an agent happens to be
  # standing in (runtime-pinned-guard). Resolve it once, and fall back to this tree
  # only when no pinned checkout exists.
  # Plan 272, fault 12: there is NO fallback to this tree. An old checkout that ran this door used to render
  # `garmr-brain` with itself as the root and switch the unit off the pin; with no pin seated nothing is rendered.
  local unit_root=""
  if command -v unit_pin_dir >/dev/null 2>&1; then unit_root="$(unit_pin_dir)"; else unit_root="${YMIR_RUNTIME_DIR:-$HOME/ymir-runtime}"; [ -d "$unit_root" ] || unit_root=""; fi
  if [ -z "$unit_root" ]; then
    printf 'garmr: no pinned runtime is seated — the units were NOT rendered (a unit is never written onto a working tree); seat the pin: bin/engine/runtime-seat.sh\n' >&2
    return 0
  fi
  local run=(sudo)
  [ "$dry" = 1 ] && run=(echo "would run:")
  # The hound's two units live in /etc and need root. A sudo that must ask for a
  # password will block an unattended refresh for ever — measured 2026-11-03, three
  # runs of Groa died here. Probe first; skip the root half with a named refusal and
  # still seat the operator's own brain timer below.
  if [ "$dry" = 1 ] || sudo -n true 2>/dev/null; then
    # The hoard is the operator's, resolved on the machine that renders (a root-run hound has
    # HOME=/root and no way to find it), so the unit carries a token and never one machine's home.
    sed -e "s|__YMIR_ROOT__|$unit_root|g" -e "s|__YMIR_OPERATOR_HOME__|$HOME_DIR|g" "$render/garmr-hound.service" \
      | "${run[@]}" tee /etc/systemd/system/garmr-hound.service >/dev/null
    sed "s|__YMIR_ROOT__|$unit_root|g" "$render/garmr-arm.service" \
      | "${run[@]}" tee /etc/systemd/system/garmr-arm.service >/dev/null
    "${run[@]}" systemctl daemon-reload
    if [ "$off" = 1 ]; then
      "${run[@]}" systemctl disable garmr-arm.service garmr-hound.service >/dev/null 2>&1 || true
    else
      "${run[@]}" systemctl enable garmr-arm.service
      "${run[@]}" systemctl restart garmr-arm.service
      "${run[@]}" systemctl enable --now garmr-hound.service
    fi
  else
    printf 'garmr: the hound needs root, and sudo is not available without a password here; its two system units were left alone (run: sudo -v, then garmr.sh install)\n' >&2
  fi
  mkdir -p "$HOME/.config/systemd/user"
  sed "s|__YMIR_ROOT__|$unit_root|g; s|__PYTHON__|$PY|g" "$render/garmr-brain.service" \
    > "$HOME/.config/systemd/user/garmr-brain.service"
  cp "$render/garmr-brain.timer" "$HOME/.config/systemd/user/garmr-brain.timer"
  # the register has the last word on where the unit points (it retargets any tree that is not the pin)
  if [ "$dry" != 1 ] && command -v unit_settle >/dev/null 2>&1; then unit_settle garmr-brain || true; fi
  as_operator systemctl --user daemon-reload
  if [ "$off" = 1 ]; then
    as_operator systemctl --user disable garmr-brain.timer >/dev/null 2>&1 || true
    printf 'garmr: units re-rendered and left OFF at the Allfather word — `garmr.sh on` raises him\n'
  else
    as_operator systemctl --user enable --now garmr-brain.timer
  fi
}

status() {
  local hound brain judged=0
  # `systemctl is-active` PRINTS the state and exits non-zero when it is not active, so the old
  # `|| echo unknown` printed two lines ("inactive" then "unknown") — a status line that argues
  # with itself. Ask, then fill in only when it said nothing.
  hound="$(systemctl is-active garmr-hound.service 2>/dev/null || true)"; [ -n "$hound" ] || hound=unknown
  brain="$(systemctl --user is-active garmr-brain.timer 2>/dev/null || true)"; [ -n "$brain" ] || brain=unknown
  [ -f "$STATE/judged.jsonl" ] && judged="$(wc -l < "$STATE/judged.jsonl" | tr -d ' ')"
  printf 'garmr{seals}:\n'
  printf '  mode                    %s\n' "$(mode_text)"
  printf '  hound (system)          %s\n' "$hound"
  printf '  brain timer (user)      %s\n' "$brain"
  printf '  audit rules armed       %s\n' "$(sudo -n auditctl -l 2>/dev/null | grep -c ymir- || true)"
  printf '  findings file           %s\n' "$([ -f "$FINDINGS" ] && wc -l < "$FINDINGS" | tr -d ' ' || echo 'none yet')"
  printf '  judged                  %s\n' "$judged"
  printf '  heartbeat               %s\n' "$(cat "$STATE/hound.heartbeat" 2>/dev/null || echo 'never')"
  printf '  paused                  %s\n' "$(reports_off && echo yes || echo no)"
  printf '  config                  %s\n' "$(GARMR_PRINT_CONFIG=1 "$PY" - <<'PY' 2>/dev/null
import sys, os
sys.path.insert(0, os.path.join(os.environ.get('ROOT','.'), 'bin/ward/garmr'))
import common
print(common.load_config()['_config_path'])
PY
)"
}

verify() {
  local fails=0
  "$PY" "$GARMR/hound.py" --once --stdout >/dev/null 2>&1 || { echo "FAIL: the hound cannot run"; fails=$((fails+1)); }
  [ -f "$FINDINGS" ] || { echo "note: no findings file yet — the hound has written nothing"; }
  local beat="$STATE/hound.heartbeat"
  if [ -f "$beat" ]; then
    local age=$(( $(date +%s) - $(date -r "$beat" +%s) ))
    [ "$age" -gt 600 ] && { echo "FAIL: the hound is silent (heartbeat ${age}s old)"; fails=$((fails+1)); }
  else
    echo "note: no heartbeat yet — the hound has not run as the service"
  fi
  systemctl is-active --quiet garmr-hound.service || { echo "note: garmr-hound.service is not active"; }
  [ "$fails" -eq 0 ] && echo "garmr: surfaces whole"
  return "$fails"
}

# ── THE SWITCH ─────────────────────────────────────────────────────────────────
# One word each way: `off` and `on`. `pause` and `resume` are the same switch under its
# older names, kept so an old script, an old runbook or an old habit still works.
#
# off  = root's marker + its readable copy, the two system units and the user timer STOPPED
#        and DISABLED, so a reboot, a `refresh` by Groa, or a re-install cannot raise him.
# on   = the marker cleared, the units enabled again and started.
#
# It is ROOT's on purpose. A guardian an ordinary process can silence is a guardian the
# intruder silences first — the smoke test asserts a non-root `off` is refused.
# What `off` does NOT do: unload the kernel's audit rules (they are auditd's, they cost
# almost nothing, and forgetting them is how a seat ends up deaf after a quiet week).
set_switch() {  # <off|on>
  local want="$1"
  local marker="$MARKER"
  local log="/var/log/ymir/garmr/pause.log"
  # --dry-run: the plan without root, so the Allfather can see the turn before he makes it.
  if [ "$dry" = 1 ]; then
    local now; now="$(date -Iseconds)"
    if [ "$want" = off ]; then
      printf 'would: write %s and %s with "%s"\n' "$marker" "$MIRROR" "$now"
      printf 'would: append "%s\toff\tby uid %s" to %s\n' "$now" "${SUDO_UID:-$UID}" "$log"
      printf 'would: systemctl stop+disable garmr-hound.service garmr-arm.service\n'
      printf 'would: systemctl --user stop+disable garmr-brain.timer\n'
    else
      printf 'would: append the on-line to %s, then remove %s and %s\n' "$log" "$marker" "$MIRROR"
      printf 'would: systemctl enable+start garmr-arm.service garmr-hound.service\n'
      printf 'would: systemctl --user enable --now garmr-brain.timer\n'
    fi
    return 0
  fi
  if [ "$(id -u)" -ne 0 ]; then
    printf 'refused: turning the guardian %s needs root — the marker is root-owned on purpose.\n' "$want" >&2
    printf 'help: sudo bin/ward/garmr.sh %s   (or %s --dry-run to see the plan)\n' "$want" "$want" >&2
    exit 1
  fi
  mkdir -p /var/log/ymir/garmr
  local now; now="$(date -Iseconds)"
  if [ "$want" = off ]; then
    printf '%s\n' "$now" > "$marker"
    write_mirror "$now"
    printf '%s\toff\tby uid %s\n' "$now" "${SUDO_UID:-$UID}" >> "$log"
    systemctl stop garmr-hound.service garmr-arm.service 2>/dev/null || true
    systemctl disable garmr-hound.service garmr-arm.service 2>/dev/null || true
    as_operator systemctl --user stop garmr-brain.timer 2>/dev/null || true
    as_operator systemctl --user disable garmr-brain.timer 2>/dev/null || true
    printf 'garmr: OFF at %s — the hound and the judgement are down, the units are disabled,\n' "$now"
    printf 'garmr: so a reboot will not raise him. The kernel audit rules stay loaded.\n'
    printf 'garmr: `sudo bin/ward/garmr.sh on` wakes him.\n'
  else
    printf '%s\ton\twas off since %s\n' "$now" "$(cat "$marker" 2>/dev/null || cat "$MIRROR" 2>/dev/null || echo unknown)" >> "$log"
    rm -f "$marker" "$MIRROR"
    systemctl enable garmr-arm.service garmr-hound.service 2>/dev/null || true
    systemctl start garmr-arm.service 2>/dev/null || true
    systemctl start garmr-hound.service 2>/dev/null || true
    as_operator systemctl --user enable --now garmr-brain.timer 2>/dev/null || true
    printf 'garmr: ON at %s — the hound is up, the judgement ticks, and the units are enabled again\n' "$now"
  fi
}

case "$cmd" in
  on|off|pause|resume)
    case "$cmd" in off|pause) want=off ;; *) want=on ;; esac
    set_switch "$want" ;;
  refresh)
    seat_units
    printf 'garmr: units re-rendered and reloaded (rules untouched)\n' ;;
  status)  status ;;
  install) arm_senses; seat_units; is_off && echo "garmr: the senses are armed but the hound stays OFF at your word (garmr.sh on)" || echo "garmr: senses armed, units seated" ;;
  start)
    if is_off; then
      printf 'refused: the hound is OFF at the Allfather word — `sudo bin/ward/garmr.sh on` raises him.\n' >&2
      exit 1
    fi
    sudo systemctl start garmr-hound.service; systemctl --user start garmr-brain.timer ;;
  stop)    sudo systemctl stop garmr-hound.service; systemctl --user stop garmr-brain.timer ;;
  restart) sudo systemctl restart garmr-hound.service; systemctl --user restart garmr-brain.timer ;;
  judge)   "$PY" "$GARMR/brain.py" --once ${dry:+--dry-run} ;;
  once)    "$PY" "$GARMR/hound.py" --once ;;
  verify)  verify ;;
  tail)    "$PY" "$GARMR/brain.py" --file "$FINDINGS" --once --dry-run | tail -n "${1:-20}" ;;
  -h|--help) usage ;;
  *) printf 'error: unknown command %s\nhelp: garmr.sh [status|off|on|install|start|stop|restart|judge|once|verify|tail]\n' "$cmd" >&2; exit 2 ;;
esac
