#!/usr/bin/env bash
# test_restart_storm.sh — the storm ward's proof, with no real fault (plan 286 P4).
#
# A planted looping unit, a planted journal and a stand-in systemctl/notify/in-call door. What is
# asserted: the unit ABOVE the limit is stopped and named with its last error; a calm unit and the
# distribution's own unit are left alone; a call held on the desk defers the audio family; the
# operator's exclude is obeyed; a second pass does not shout twice; a dry run touches nothing.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
N="$HERE/../restart-storm.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0; ok() { printf 'ok   %s\n' "$1"; }; no() { printf 'FAIL %s\n' "$1"; fail=1; }

mkdir -p "$T/home/config" "$T/bin"
: > "$T/stops" ; : > "$T/notify.log"

# ── the machine: a looping house unit, a calm one, a looping distribution unit ──
cat > "$T/bin/systemctl" <<'S'
#!/usr/bin/env bash
here="$(cd "$(dirname "$0")/.." && pwd)"
down() { grep -qx "$1" "$here/stops" 2>/dev/null; }
case "$*" in
  *list-units*)
    printf 'loop-a.service loaded activating auto-restart Planted loop\n'
    printf 'snotra-watch.service loaded activating auto-restart The meeting ear, looping\n'
    printf 'calm.service loaded active running Perfectly calm\n'
    printf 'vendor-loop.service loaded activating auto-restart The distribution own loop\n'
    exit 0 ;;
  *stop*)
    for a in "$@"; do case "$a" in stop) ;; *) printf '%s\n' "$a" >> "$here/stops" ;; esac; done
    exit 0 ;;
  *show*)
    # A unit this ward stopped is DOWN on the next ask: that is what a real stop does.
    if down loop-a.service; then a_state=inactive; a_sub=dead; else a_state=activating; a_sub=auto-restart; fi
    if down snotra-watch.service; then s_state=inactive; s_sub=dead; else s_state=activating; s_sub=auto-restart; fi
    printf 'Id=loop-a.service\nActiveState=%s\nSubState=%s\nNRestarts=12\nFragmentPath=%s/.config/systemd/user/loop-a.service\nRestart=always\n\n' \
      "$a_state" "$a_sub" "$HOME"
    printf 'Id=snotra-watch.service\nActiveState=%s\nSubState=%s\nNRestarts=14\nFragmentPath=%s/.config/systemd/user/snotra-watch.service\nRestart=always\n\n' \
      "$s_state" "$s_sub" "$HOME"
    printf 'Id=calm.service\nActiveState=active\nSubState=running\nNRestarts=0\nFragmentPath=%s/.config/systemd/user/calm.service\nRestart=on-failure\n\n' "$HOME"
    printf 'Id=vendor-loop.service\nActiveState=activating\nSubState=auto-restart\nNRestarts=40\nFragmentPath=/usr/lib/systemd/user/vendor-loop.service\nRestart=always\n'
    exit 0 ;;
  *) exit 0 ;;
esac
S
chmod +x "$T/bin/systemctl"

cat > "$T/bin/journalctl" <<'S'
#!/usr/bin/env bash
unit=""; for a in "$@"; do case "$a" in *.service) unit="$a" ;; esac; done
case "$unit" in
  loop-a.service)
    printf 'loop-a.service: Main process exited, code=exited, status=1/FAILURE\n'
    i=1; while [ "$i" -le 12 ]; do printf 'loop-a.service: Scheduled restart job, restart counter is at %s.\n' "$i"; i=$((i+1)); done
    printf "loop-a.service: Failed to load environment files: No such file or directory\n" ;;
  snotra-watch.service)
    i=1; while [ "$i" -le 14 ]; do printf 'snotra-watch.service: Scheduled restart job, restart counter is at %s.\n' "$i"; i=$((i+1)); done
    printf 'snotra-watch.service: Main process exited, code=exited, status=2/INVALIDARGUMENT\n' ;;
  calm.service) printf 'calm.service: Started perfectly calm.\n' ;;
  # the distribution's own unit: the journal answers, the ward must still not touch it
  vendor-loop.service)
    i=1; while [ "$i" -le 40 ]; do printf 'vendor-loop.service: Scheduled restart job, restart counter is at %s.\n' "$i"; i=$((i+1)); done ;;
  *) ;;
esac
exit 0
S
chmod +x "$T/bin/journalctl"

cat > "$T/bin/notify" <<S
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$T/notify.log"
S
chmod +x "$T/bin/notify"

printf '#!/usr/bin/env bash\nexit 0\n' > "$T/bin/in-call-free"; chmod +x "$T/bin/in-call-free"
printf '#!/usr/bin/env bash\nprintf "Discord — Microphone\\n"\n' > "$T/bin/in-call-held"; chmod +x "$T/bin/in-call-held"

W() {  # run the ward in the planted world
  env YMIR_HOME="$T/home" YMIR_SOAK_SYSTEMCTL="$T/bin/systemctl" \
      YMIR_SOAK_JOURNALCTL="$T/bin/journalctl" YMIR_SOAK_NOTIFY="$T/bin/notify" \
      YMIR_SOAK_IN_CALL="${IN_CALL:-$T/bin/in-call-free}" \
      bash "$N" "$@" 2>&1
}
ledger="$T/home/state/soak/services/$(date +%F).jsonl"

# ── 1. a storm is stopped, named, and carried with its last error ──────────────
out="$(W --pass --threshold 10)"
grep -qx 'loop-a.service' "$T/stops" && ok "the storming unit is stopped" || no "loop-a was not stopped: $(cat "$T/stops")"
grep -q 'still down' /dev/null 2>/dev/null || true
grep -q 'restart storm: loop-a.service restarted 12 times in 60 min (limit 10) — stopped' "$T/notify.log" \
  && ok "the Allfather is told WHICH unit, how many times, and what was done" || no "notify: $(cat "$T/notify.log")"
grep -q 'No such file or directory' "$T/notify.log" && ok "the last error travels with the message" \
  || no "the last error is missing from the message"
grep -q '"kind":"storm","name":"loop-a.service"' "$ledger" 2>/dev/null \
  && ok "the stop is a row in the same ledger the sampler writes" || no "no storm row in $ledger"
grep -q '"action":"stopped"' "$ledger" 2>/dev/null && ok "the row says what was done" || no "row action: $(tail -n1 "$ledger" 2>/dev/null)"
grep -q '"source":"journal"' "$ledger" 2>/dev/null && ok "the row says which source counted" || no "row source"
grep -q 'calm.service' "$T/stops" && no "a calm unit was stopped" || ok "a calm unit is left alone"
grep -q 'vendor-loop.service' "$T/stops" && no "the distribution's own unit was stopped" \
  || ok "the distribution's own unit is not the house's to stop"

# ── 2. a second pass inside the cooldown does not shout twice ─────────────────
before="$(wc -l < "$T/notify.log")"
W --pass --threshold 10 > /dev/null
after="$(wc -l < "$T/notify.log")"
[ "$before" = "$after" ] && ok "the same storm is not re-reported inside the cooldown" \
  || no "it shouted again ($before → $after)"

# ── 3. a call held on the desk defers the audio family, not the rest ─────────
rm -f "$T/stops" "$T/notify.log"; : > "$T/notify.log"; rm -f "$T/home/state/soak/storm-state.json"
IN_CALL="$T/bin/in-call-held" W --pass --threshold 10 > /dev/null
grep -qx 'snotra-watch.service' "$T/stops" 2>/dev/null && no "the meeting ear was stopped during a call" \
  || ok "the audio family is deferred while a call is held"
grep -qx 'loop-a.service' "$T/stops" 2>/dev/null && ok "a non-audio storm is still stopped during a call" \
  || no "loop-a should still be stopped while a call is held: $(cat "$T/stops" 2>/dev/null)"
grep -q 'deferred: a call is held' "$T/notify.log" && ok "the deferral is said, not silent" \
  || no "no deferral message: $(cat "$T/notify.log")"

# ── 4. the operator's exclude is obeyed ───────────────────────────────────────
printf 'restart_storm:\n  threshold: 10\n  exclude: "^loop-a"\n' > "$T/home/config/soak.yaml"
rm -f "$T/stops" "$T/notify.log" "$T/home/state/soak/storm-state.json"; : > "$T/notify.log"
W --pass > /dev/null
grep -qx 'loop-a.service' "$T/stops" 2>/dev/null && no "an excluded unit was stopped" \
  || ok "restart_storm.exclude keeps a unit out of the ward's hand"

# ── 5. the ward switched off reports, and stops nothing ─────────────────────
printf 'restart_storm:\n  enabled: false\n  threshold: 10\n' > "$T/home/config/soak.yaml"
rm -f "$T/stops" "$T/notify.log" "$T/home/state/soak/storm-state.json"; : > "$T/notify.log"
W --pass > /dev/null
[ -s "$T/stops" ] && no "with the ward off, a unit was stopped" || ok "enabled: false stops nothing"
grep -q 'reporting only' "$T/notify.log" && ok "with the ward off, the storm is still reported" \
  || no "the reporting-only message is missing"

# ── 6. a dry run touches nothing ─────────────────────────────────────────────
printf 'restart_storm:\n  threshold: 10\n' > "$T/home/config/soak.yaml"
rm -f "$T/stops" "$T/notify.log" "$T/home/state/soak/storm-state.json"; : > "$T/notify.log"
dry="$(W --pass --dry-run)"
[ -s "$T/stops" ] && no "a dry run stopped a unit" || ok "a dry run stops nothing"
[ -s "$T/notify.log" ] && no "a dry run sent a message" || ok "a dry run sends nothing"
grep -q '"action":"would-stop"' <<<"$dry" && ok "a dry run says what it WOULD do" \
  || no "dry run output: $dry"

# ── 7. when the journal cannot be read, the sampler's ledger is the count ─────
printf '#!/usr/bin/env bash\nexit 1\n' > "$T/bin/journal-blind"; chmod +x "$T/bin/journal-blind"
mkdir -p "$T/home/state/soak/services"
LED="$T/home/state/soak/services/$(date +%F).jsonl"
python3 - "$LED" <<'PY2'
import datetime, json, sys
now = datetime.datetime.now(datetime.timezone.utc)
rows = []
for minutes_ago, restarts in ((40, 3), (8, 15)):
    ts = (now - datetime.timedelta(minutes=minutes_ago)).strftime("%Y-%m-%dT%H:%M:%SZ")
    rows.append({"ts": ts, "pass": "planted", "host": "planted", "kind": "service",
                 "scope": "user", "name": "loop-a.service", "state": "activating",
                 "sub": "auto-restart", "restarts": restarts})
with open(sys.argv[1], "a") as fh:
    for row in rows:
        fh.write(json.dumps(row) + "\n")
PY2
rm -f "$T/stops" "$T/notify.log" "$T/home/state/soak/storm-state.json"; : > "$T/notify.log"
printf 'restart_storm:\n  threshold: 10\n' > "$T/home/config/soak.yaml"
env YMIR_HOME="$T/home" YMIR_SOAK_SYSTEMCTL="$T/bin/systemctl" \
    YMIR_SOAK_JOURNALCTL="$T/bin/journal-blind" YMIR_SOAK_NOTIFY="$T/bin/notify" \
    YMIR_SOAK_IN_CALL="$T/bin/in-call-free" \
    bash "$N" --pass > /dev/null 2>&1
grep -qx 'loop-a.service' "$T/stops" 2>/dev/null \
  && ok "with the journal blind, the ledger's restart deltas are the count" \
  || no "the ledger fallback did not stop the storming unit"
grep -q '"source":"ledger"' "$LED" 2>/dev/null && ok "the row says the ledger answered" \
  || no "the source was not recorded as the ledger"
rm -f "$LED"

# ── 8. the config's threshold is the one used, and --status says where it came from
printf 'restart_storm:\n  threshold: 40\n' > "$T/home/config/soak.yaml"
rm -f "$T/stops" "$T/home/state/soak/storm-state.json"
W --pass > /dev/null
grep -qx 'loop-a.service' "$T/stops" 2>/dev/null && no "a threshold of 40 must not stop a 12-restart unit" \
  || ok "restart_storm.threshold from the home's config is the limit that is used"
W --status | grep -q '^threshold,40 \[config\]' && ok "--status names the value AND its source" \
  || no "--status did not name the config's threshold"

exit $fail
